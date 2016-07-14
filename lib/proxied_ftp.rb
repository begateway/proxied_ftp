require 'net/ftp'
require 'base64'

class ProxiedFtp < Net::FTP
  attr_reader :p_host, :p_port

  def self.open(p_host, p_port, host, user = nil, passwd = nil, acct = nil)
    if block_given?
      ftp = new(p_host, p_port, host, user, passwd, acct)
      begin
        yield ftp
      ensure
        ftp.close
      end
    else
      new(p_host, p_port, host, user, passwd, acct)
    end
  end

  def initialize(p_host, p_port, host = nil, user = nil, passwd = nil, acct = nil)
    @p_host = p_host
    @p_port = p_port
    super(host, user, passwd, acct)
  end

  private

  def open_socket(host, port)
    return Timeout.timeout(@open_timeout, Net::OpenTimeout) do
      if defined? SOCKSSocket and ENV["SOCKS_SERVER"]
        @passive = true
        sock = SOCKSSocket.open(host, port)
      else
        # Every connection to the ftp server goes through our proxy server
        proxy = TCPSocket.open(p_host, p_port)
        proxy.write("CONNECT #{host}:#{port} HTTP/1.1")
        proxy.write(CRLF)
        proxy.write(CRLF)

        sock = proxy
      end
      io = BufferedSocket.new(sock)
      io.read_timeout = @read_timeout
      # The following two lines of code is used for escaping unneccessary
      # information from the stream ("HTTP/1.1 200 Connection established" and
      # ""(empty line))
      io.gets
      io.gets
      io
    end
  end
end
