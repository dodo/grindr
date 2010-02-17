#!/usr/bin/env ruby

require 'xmpp4r-observable'
require 'control'

#Jabber::debug = true

if ARGV.size < 2
  puts "Usage: #{$0} <superfeedr-jid> <superfeedr-password>"
  exit
end

jid, pw = ARGV[0], ARGV[1]
jid = "#{jid}@superfeedr.com" unless jid.index('@')

$im = Jabber::Observable.new(jid, pw)
$im.status :xa, 'At your service!'

#pubsub = Jabber::Observable::PubSub.new($im, 'firehoser.superfeedr.com')
class Handler
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

o = Handler.new
$im.add_observer(:message, o)

puts "Running"
Thread.stop
