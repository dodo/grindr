require 'xmpp4r'
require 'superfeedr'
require 'load'
require 'control'
require 'time'


class Client
  attr_reader :jid

  def initialize(jid, pw, host = nil, port=5222)
    @presence, @status_message = nil, ""
    @client, @pw, @host, @port = nil, pw, host, port
    @jid = Jabber::JID.new jid
    @msg_cb = nil
  end

  def connect!
    @connect_mutex ||= Mutex.new
    return if @connect_mutex.locked?
    @connect_mutex.lock
    disconnect! if connected?

    c = Jabber::Client.new @jid
    c.connect @host, @port
    c.auth @pw
    @client = c
    status @presence, @status_message
    client.add_message_callback @msg_cb unless @msg_cb.nil?
    @connect_mutex.unlock
  end

  def disconnect!
    if connected?
      begin
          @client.close
          @client = nil
        rescue Errno::EPIPE, IOError => e
          nil
      end
    end
  end

  def reconnect!
    disconnect!
    connect!
  end

  def connected?
    @client.respond_to?(:is_connected?) && @client.is_connected?
  end

  def client
    connect! unless connected?
    @client
  end

  def status(presence, message)
    @presence = presence
    @status_message = message
    stat_msg = Jabber::Presence.new @presence, @status_message
    send!(stat_msg)
  end

  def deliver(jid, message, xhtml=nil, type=:chat, state=:active)
    msg = Jabber::Message.new jid, message
    unless xhtml.nil?
      if xhtml.is_a? Array
          xhtml.each { |elem| msg.add_element(elem) }
        else
          msg.add_element xhtml
      end
    end
    msg.chat_state = state
    msg.type = type
    send! msg
  end

  def iscomposing(jid, type=:chat)
    msg = Jabber::Message.new jid
    msg.chat_state = :composing
    msg.type = type
    msg.from = @jid
    send! msg
  end

  def add_message_callback(&block)
    @msg_cb = block
    client.add_message_callback &block
  end

  private
  def send!(msg)
    attempts = 0
    begin
        attempts += 1
        client.send msg
      rescue Errno::EPIPE, IOError => e
        sleep 1
        reconnect!
        retry unless attempts > 3
        raise e
      rescue Errno::ECONNRESET => e
        sleep (attempts^2) * 60 + 60
        reconnect!
        retry unless attempts > 3
        raise e
    end
  end

end



class Handler
  attr_reader :users, :im
  def initialize(im)
    @im, @users, @strangers = im, {}, {}
  end
  def update(msg)
    begin
        text, jid = msg.body.strip.to_s, msg.from
        unless text.start_with? "?OTR"
          case CONFIG['mode']
            when 'public' then
              begin
                add_stranger(jid) unless @strangers.has_key?(from(jid)) || @users.has_key?(from(jid))
                if @strangers.has_key? from(jid)
                    @strangers[from jid].receive(text)
                  else
                    @users[from jid].receive(text) if @users.has_key? from(jid)
                end
              end
            when 'private' then @users[from jid].receive(text) if @users.has_key? from(jid)
          end
        end
      rescue Exception => e
        puts "errör:" + e.to_s
        puts e.backtrace
    end
  end
  def add_stranger(jid)
    @strangers[from jid] = Unregistered.new(self, @im, jid)
  end
  def remove_stranger(jid)
    @strangers.delete from(jid)
  end
  def add_user(jid, welcome = true)
    case CONFIG['mode']
      when 'public'  then user = Registered
      when 'private' then user = Private
    end
    @users[from jid] = user.new(@im, jid, welcome)
  end

  private

  def from(jid)
    jid.node + "@" + jid.domain
  end
end



class Notifier
  def initialize(h)
    @h = h
  end
  def update(event)
    begin
        p "arrived", @h.users.any?
        case CONFIG['mode'] 
          when 'private' then @h.users.first[1].notify(event) if @h.users.any?
          when 'public'  then @h.users.values.each do |user| # FIXME bottle neck
            user.notify(event) if user.get("feeds").include? event.feed_url
          end
        end
      rescue Exception => e
        puts "errör:" + e.to_s
        puts e.backtrace

    end
  end
end

