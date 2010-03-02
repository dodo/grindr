#!/usr/bin/env ruby

require 'xmpp4r-observable'
require 'control'

CONFIG = load_config
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
    @users = {}
  end
  def update(what, msg)
    text = msg.body.strip
    from = msg.from.node + "@" + msg.from.domain
    add_user(msg.from) unless @users.has_key? from
    @users[from].receive(text) unless text.start_with? "?OTR"
  end
  def add_user(jid)
    from = jid.node + "@" + jid.domain
    @users[from] = UserController.new($im, jid)
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
      when 'public'  then @h.users.each { |user| user.notify(event) } ### FIXME add user specific notifications
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
$im.add_observer(:message, h)
$im.add_observer(:event, n)
$im.add_observer(:"stream:error", b) # hehe .. well .. i tried it .. :p

puts "Running"
Thread.stop
