#!/usr/bin/env ruby

puts "starting ..."

require 'xmpp4r-observable'
require 'control'

Jabber::debug = true

unless ['private', 'public'].include? CONFIG['mode']
  puts "Mode not right configured.","your: #{CONFIG['mode']}","should: private or public"
  exit 1
end

jid, pw = CONFIG['jid'], CONFIG['password']
jid = "#{jid}@superfeedr.com" unless jid.index('@')

$im = Jabber::Observable.new(jid, pw)
$im.status :xa, 'At your service!'

class Handler
  attr_reader :users
  def initialize
    @users, @strangers = {}, {}
  end
  def update(what, msg)
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
  end
  def add_stranger(jid)
    @strangers[from jid] = Unregistered.new(self, $im, jid)
  end
  def remove_stranger(jid)
    @strangers.delete from(jid)
  end
  def add_user(jid, welcome = true)
    @users[from jid] = Registered.new($im, jid, welcome)
  end

  private

  def from(jid)
    jid.node + "@" + jid.domain
  end
end

class Notifier
  def initialize(h)
    @h = h
    @pubsub = Jabber::Observable::PubSub.new($im, 'firehoser.superfeedr.com')
  end
  def update(what, event)
    p "arrived", @h.users.any?
    case CONFIG['mode']
      when 'private' then @h.users.first[1].notify(event) if @h.users.any?
      when 'public'  then @h.users.values.each { |user| user.notify(event) } ### FIXME add user specific notifications
    end
  end
end
class Blackhole
  def update(what, event)
  end
end

h = Handler.new
n = Notifier.new(h)
b = Blackhole.new
h.add_user(Jabber::JID.new(CONFIG['private']['jid'])) if CONFIG['mode'] == 'private'
case CONFIG['mode']
  when 'private' then $im.add_observer(:message, h)
  when 'public'  then
   begin
     jid, pw = CONFIG['public']['jid'], CONFIG['public']['password']
     if jid == CONFIG['jid']
         $im.add_observer(:message, h)
       else
         $public = Jabber::Observable.new(jid, pw)
         $public.status :xa, 'At your service!'
         $public.add_observer(:message, h)
         $public.add_observer(:"stream:error", b)
     end
   end
end
$im.add_observer(:event, n)
$im.add_observer(:"stream:error", b) # hehe .. well .. i tried it .. :p

puts "* Running"
Thread.stop
