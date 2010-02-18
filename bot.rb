#!/usr/bin/env ruby

require 'xmpp4r-observable'
require 'control'

Jabber::debug = true

if ARGV.size < 2
  puts "Usage: #{$0} <superfeedr-jid> <superfeedr-password>"
  exit
end

jid, pw = ARGV[0], ARGV[1]
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
    @users[from] = UserController.new($im, msg.from) unless @users.has_key? from
    @users[from].receive(text) unless text.start_with? "?OTR"
  end
end

class Notifier
  def initialize(h)
    @h = h
    @pubsub = Jabber::Observable::PubSub.new($im, 'firehoser.superfeedr.com')
  end
  def update(what, event)
    p "arrived", @h.users.any?
    @h.users.first[1].notify(event) if @h.users.any? ### FIXME
  end
end
class Blackhole
  def update(what, event)
  end
end

h = Handler.new
n = Notifier.new(h)
b = Blackhole.new
$im.add_observer(:message, h)
$im.add_observer(:event, n)
$im.add_observer(:"stream:error", b)

puts "Running"
Thread.stop
