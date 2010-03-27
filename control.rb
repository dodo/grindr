require 'xmpp4r/dataforms'
require 'time'
require 'load'

$manual = {:help => "help\nShow the list of all given commands and with a little description.",
           :man => "man <cmd>\nShow a manual of the given command.",
           :mode => "mode <format>\nChange the formatting of the notifications.\n"+
                    "available formats:\n    title -- show only the titles.\n"+
                    "    all -- show all given information.\n    ? -- show current mode.",
           :add => "add <feedurl>\nSubscribe to given feedurl.\nSeperate multiple feeds by space.",
           :remove => "remove <feedurl>\nUnsubscribe from given feedurl.\nSeperate multiple feeds by space.",
           :format => "format <on|off>\nSet xhtml formatting on or off."}

class User

  def initialize(im, to, methods=[], functions=[])
    @im,@to,@methods,@functions,@use_xhtml = im,to,methods,functions,false
  end

  def deliver(text, xhtml)
    xhtml = nil unless @use_xhtml
    x = xhtml.nil? ? nil : gen_xhtml(xhtml)
    @im.deliver @to, text, x
  end

  def iscomposing
    @im.iscomposing @to
  end

  def receive(msg)
    begin
      if @methods.include? msg.chomp.to_sym
        send msg.chomp.to_sym
      elsif @functions.include? msg.split[0].chomp.to_sym
        send msg.split[0].chomp.to_sym, *msg.split[1..-1]
      else
        deliver "command not found", nil
      end
    rescue Exception => e
      deliver "an error occurred:\n"+e.to_s, nil
    end
  end

  private

  def gen_xhtml(text)
    h = REXML::Element.new "html"
    h.add_namespace 'http://jabber.org/protocol/xhtml-im'
    b = REXML::Element.new "body"
    b.add_namespace 'http://www.w3.org/1999/xhtml'
    a = REXML::Element.new "active"
    a.add_namespace 'http://jabber.org/protocol/chatstates'
    t = REXML::Text.new text, false, nil, true, nil, %r/.^/
    b.add t
    h.add b
    [a, h]
  end

end


class Unregistered < User

  def initialize(handler, im, to)
    @handler, @register_state = handler, false
    puts "* recognizing stranger "+to.to_s
    m = [:info,:help,:ping,:test,:register]
    super im, to, m
    deliver "Welcome to #{CONFIG['name']}! You're just an unregistered Stranger. Type help for overview."
  end

  def deliver(text, _ = nil)
    super(text, nil) # disabled xhtml for unregistered users
  end

  def receive(msg)
    if registering?
        finish_register if check_register msg
        @register_state = false  
      else
        super
    end
  end

  def register
    @a, @b = 23, 19
    while @a + @b == 42
      @a = 1 + rand(100)
      @b = 1 + rand(100)
    end
    deliver "[REGISTERINFO]" ###FIXME
    deliver "Before you're registered I want to confirm that you're a REAL self thinking organismn.\nPlease just answer this little question:\nWhat is the sum of #{@a} and #{@b}?"
    @register_state = true
  end

  def check_register(msg)
    if ["42","fourtytwo","fourty two","fourty-two"].include? msg.chomp.downcase
        deliver "Good try. <3"
        result = false
      else
        result = msg.to_i == @a + @b
        deliver "Your answer is incorrect." unless result
    end
    result
  end

  def finish_register
    begin
    @handler.remove_stranger @to
    @handler.add_user @to, false
    rescue Exception => e
      deliver "an error occurred:\n"+e.to_s
    end
    deliver "Congratulations! You're now a registered user."
  end

  def ping
    deliver "pong"
  end

  def test
    deliver "Yepp. I'm right here."
  end

  def help
    text = <<eos
[#{CONFIG['name']}] Commands:
info -- show infos about this service
help -- show this help
register -- try this to get registered
eos
    deliver text[0..-2]
  end

  def info ##FIXME
    text = <<eos
[#{CONFIG['name']}] -- superfeedr message passing service bot:
[BOTINFO]
eos
    deliver text[0..-2]
  end

  private

  def registering?
    @register_state
  end

end


class Private < User

  def initialize(im, to, welcome = true)
    puts "* add user "+to.to_s
    m = [:on,:off,:list,:help,:ping,:test,:easteregg]
    f = [:man,:add,:remove,:mode,:format,:status]
    super im, to, m, f
    @mode       = get('mode').to_sym
    @use_xhtml  = get 'use xhtml'
    @use_status = get 'use status'
    plain = "Welcome to #{CONFIG['name']}! Type help for overview. Current mode is #{@mode.to_s}."
    xhtml = "Welcome to <i>#{CONFIG['name']}</i>! Type <b>help</b> for overview. Current mode is <b>#{@mode.to_s}</b>."
    deliver plain, xhtml if welcome
  end

  def get(key)
    DB.get @to.to_s, key
  end

  def set(key, value)
    DB.set @to.to_s, key, value
  end

  def help
    text = <<eos
[#{CONFIG['name']}] Commands:
list -- listing feeds
on -- enable notifications
off -- disable notification
add <feedurl> -- adding a feed
remove <feed> -- removing a feed
mode <format> -- set notification format
man <command> -- show a manual of the command
format <on|off> -- set formatting on or off
status <on|off> -- set status report on or off
help -- show this help
eos
    xhtml = <<eos
[#{CONFIG['name']}] Commands:<br/>
<b>list</b> -- listing feeds<br/>
<b>on</b> -- enable notifications<br/>
<b>off</b> -- disable notification<br/>
<b>add &lt;feedurl&gt;</b> -- adding a feed<br/>
<b>remove &lt;feed&gt;</b> -- removing a feed<br/>
<b>mode &lt;format&gt;</b> -- set notification format<br/>
<b>man &lt;command&gt;</b> -- show a manual of the command<br/>
<b>format &lt;on|off&gt;</b> -- set formatting on or off<br/>
<b>status &lt;on|off&gt;</b> -- set status report on or off<br/>
<b>help</b> -- show this help
eos
    deliver text[0..-2], xhtml[0..-2]
  end

  def list
    deliver "requesting feeds ...", nil
    iscomposing
    Superfeedr.subscriptions do |page, feeds|
      unless feeds.empty? && page != 1
        f = feeds.empty? ? "no feeds" : feeds.join("\n")
        deliver "Feeds:   [page #{page}]\n#{f}", nil
      end
    end
  end

  def on
    deliver "not yet implemented.", nil
  end

  def off
    deliver "not yet implemented.", nil
  end

  def add(*feedlist)
    deliver "requesting subscription ...", nil
    iscomposing
    Superfeedr.subscribe(feedlist) do |feeds|
      f = feeds.empty? ? "no feeds" : feeds.join("\n")
      deliver "subscribed to:\n#{f}", nil
    end
  end

  def remove(*feedlist)
    deliver "requesting unsubscription ...", nil
    iscomposing
    Superfeedr.unsubscribe(feedlist) do |feeds|
      f = feeds.empty? ? "no feeds" : feeds.join("\n")
      deliver "unsubscribed from:\n#{f}", nil
    end
  end

  def mode(m="?")
    e = false
    case m
      when "?"     then e=true;deliver "current mode is "+@mode.to_s, "current mode is <b>#{@mode.to_s}</b>"
      when "title" then @mode = :title
      when "all"   then @mode = :all
      else e=true;deliver "mode #{m} not found.", "mode <b>#{m}</b> not found."
    end
    set 'mode', @mode.to_s
    deliver "set mode to " + m, "set mode to <b>#{m}</b>" unless e
  end

  def format(f="?")
    e, s = false, @use_xhtml&&"on"||!@use_xhtml&&"off"
    case f
      when "?"   then e=true;deliver "current formatting is "+s, "current formatting is <b>#{s}</b>"
      when "off" then @use_xhtml = false
      when "on"  then @use_xhtml = true
      set 'use xhtml', @use_xhtml
      else e=true;deliver "format #{f} not found.", "format <b>#{f}</b> not found."
    end
    deliver "set formatting " + f, "set formatting <b>#{f}</b>" unless e
  end

  def status(s="?")
    e, o = false, @use_status&&"on"||!@use_status&&"off"
    case s
      when "?"   then e=true;deliver "current status is "+o, "current status is <b>#{o}</b>"
      when "off" then @use_status = false
      when "on"  then @use_status = true
      set 'use status', @use_status
      else e=true;deliver "status #{s} not found.", "status <b>#{s}</b> not found."
    end
    deliver "set status report " + s, "set status report <b>#{s}</b>" unless e
  end

  def man(cmd)
    if $manual.include? cmd.chomp.to_sym
      deliver cmd+" manual:\n"+ $manual[cmd.chomp.to_sym], nil
    else
      deliver "manual for command '#{cmd}' not found.", nil
    end
  end

  def ping
    deliver "pong", nil
  end

  def test
    deliver "Yepp. I'm right here.", nil
  end

  def easteregg
    deliver "You found it ;P", "<span style='font-size: small;'>You found it ;P</span>"
  end

  def notify(notification)
    p "here too"
    begin
      notification.entries.each do |entry|
        unless entry.to_s.strip.empty?
          p entry, entry.to_s, entry.methods
          a, b, syms = {}, {}, {}
          a[:title] = entry.title.to_s
          a[:author] = entry.authors.empty? ? "unknown" : entry.authors.map{|a|a.name}.join(", ")
          a[:link] = entry.links.empty? ? "empty" : entry.links.first.href.to_s # FIXME extract more infos ..
          a[:published] = entry.published.to_s
          a[:content] = entry.summary # BUG filter xhtml-im malformed stuff out (eg links)
          xcontent = a[:content].empty? ? "" : '<br/>'+a[:content].gsub("&", "&amp;")

          a.each {|k,v| b[k] = v.gsub("&", "&amp;") }
          deliver *case @mode
            when :title then
              plain = "[#{a[:published]}]   #{a[:title]}   on [ #{a[:link]} ]"
              xhtml = "<span style='font-size: small;'>[#{b[:published]}]</span>  <b>#{b[:title]}</b>  <span style='font-size: small;'><i>on [ <a href='#{b[:link]}'>#{b[:link]}</a> ]</i></span>"
              [plain,xhtml]
            when :all then
              plain = "#{a[:title]}\n// Posted [#{a[:published]}] from [#{a[:author]}] on [ #{a[:link]} ]\n#{a[:content]}".strip.chomp
              xhtml = "<b>#{b[:title]}</b><span style='font-size: small;'><br/>\n// Posted [#{b[:published]}] from [#{b[:author]}] <i>on [ <a href='#{b[:link]}'>#{b[:link]}</a> ]</i></span>\n#{xcontent}".strip.chomp
              [plain,xhtml]
          end
        end
      end
      if @use_status
        title = notification.message_status
        feed = notification.feed_url
        nextf = notification.next_fetch
        fetch = "[this text is gone :(]"
        code = notification.http_status

        diff, nextf = nextf - Time.now(), nextf.to_s
        h, m, s = diff.div(3600), diff.div(60), "%.2f" % (diff % 60)
        time = [ (h.zero? ? nil : "#{h}h"), (m.zero? ? nil : "#{m}m"), "#{s}s"].compact.join " "
        deliver "[#{code}] #{title}\n#{fetch}. Next fetch in #{time} (#{nextf}).  [ #{feed} ]","<span style='font-size: small;'>[#{code}] #{title}<br/>#{fetch}. Next fetch in <b>#{time}</b> (#{nextf}).  <i>[ <a href='#{feed}'>#{feed}</a> ]</i></span>"
      end
    rescue Exception => e
      deliver "errör: "+e.to_s, nil
      puts e.backtrace
    end
  end

end

class Registered < Private

  def initialize(im, to, welcome = true)
    DB.create to.to_s
    super
    @methods << :global
  end

  def global
    deliver "requesting feeds ...", nil
    iscomposing
    Superfeedr.subscriptions do |page, feeds|
      unless feeds.empty? && page != 1
        f = feeds.empty? ? "no feeds" : feeds.join("\n")
        deliver "Feeds:   [page #{page}]\n#{f}", nil
      end
    end
  end

  def list
    feeds = get "feeds"
    f = feeds.empty? ? "no feeds" : feeds.join("\n")
    deliver "Feeds:\n#{f}", nil
  end

  def add(*feedlist)
    deliver "requesting subscription ...", nil
    iscomposing
    Superfeedr.subscribe(feedlist) do |feeds|
      set "feeds", (get("feeds") + feeds).uniq
      f = feeds.empty? ? "no feeds" : feeds.join("\n")
      deliver "subscribed to:\n#{f}", nil
    end
  end

  def remove(*feedlist)
    deliver "requesting unsubscription ...", nil
    iscomposing
    removelist = feedlist.clone.uniq
    feedlist.each do |feed|
      DB.users.each do |user| # FIXME another bottle neck
        removelist.delete(feed) if DB.get(user, "feeds").include? feed
      end
    end
    set "feeds", get("feeds") - feedlist # FIXME what if unsubscribe fail?
    f = feedlist.empty? ? "no feeds" : feedlist.uniq.join("\n")
    deliver "unsubscribed from:\n#{f}", nil
    Superfeedr.unsubscribe(removelist) do |feeds|
    end
  end

  def help
    text = <<eos
[#{CONFIG['name']}] Commands:
list -- listing feeds
global -- listing all feeds of this service
on -- enable notifications
off -- disable notification
add <feedurl> -- adding a feed
remove <feed> -- removing a feed
mode <format> -- set notification format
man <command> -- show a manual of the command
format <on|off> -- set formatting on or off
status <on|off> -- set status report on or off
help -- show this help
eos
    xhtml = <<eos
[#{CONFIG['name']}] Commands:<br/>
<b>list</b> -- listing feeds<br/>
<b>global</b> -- listing all feeds of this service<br/>
<b>on</b> -- enable notifications<br/>
<b>off</b> -- disable notification<br/>
<b>add &lt;feedurl&gt;</b> -- adding a feed<br/>
<b>remove &lt;feed&gt;</b> -- removing a feed<br/>
<b>mode &lt;format&gt;</b> -- set notification format<br/>
<b>man &lt;command&gt;</b> -- show a manual of the command<br/>
<b>format &lt;on|off&gt;</b> -- set formatting on or off<br/>
<b>status &lt;on|off&gt;</b> -- set status report on or off<br/>
<b>help</b> -- show this help
eos
    deliver text[0..-2], xhtml[0..-2]
  end

end

