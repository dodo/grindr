#!/usr/bin/env ruby

puts "starting ..."

require 'load'
require 'client'
require 'superfeedr'

begin
  Jabber::debug = true
  Skates.logger.level = Log4r::DEBUG

  case CONFIG['mode']
    when 'private' then jid, pw = CONFIG['jid'], CONFIG['password']
    when 'public'  then jid, pw = CONFIG['public']['jid'], CONFIG['public']['password']
  end
  jid = "#{jid}@superfeedr.com" unless jid.index('@')
  im = Client.new(jid+"/chatbotr", pw)
  im.status :chat, 'At your service!'

  handler = Handler.new im
  notifier = Notifier.new handler
  handler.add_user(Jabber::JID.new(CONFIG['private']['jid'])) if CONFIG['mode'] == 'private'


  Thread.start {
     p "#"*90, "try to connect to superfeedr ..."
    jid, pw = CONFIG['jid'], CONFIG['password']
    jid = "#{jid}@superfeedr.com" unless jid.index('@')
    Superfeedr.connect(jid+"/pubsubbotr", pw) do
      p "#"*90, "yay .. its connected!"
      Superfeedr.on_notification { |notification| notifier.update notification }
    end
  }

  im.add_message_callback do |message|
    if message.type == :error or message.body.nil?
        p "*"*90,"hack"
        #Superfeedr.on_stanza message # dirty hack . und geht auch nich :(
        p message.from, message.to
      else
        p "-"*90, "argg"
        handler.update message
    end
  end

  puts "* Running"
  Thread.stop
ensure
  puts "... stopping"
  DB.close
end

