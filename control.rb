require 'xmpp4r/dataforms'
require 'time'
require 'yaml'

$manual = {:help => "help\nShow the list of all given commands and with a little description.",
           :man => "man <cmd>\nShow a manual of the given command.",
           :mode => "mode <format>\nChange the formatting of the notifications.\n"+
                    "available formats:\n    title -- show only the titles.\n"+
                    "    all -- show all given information.\n    ? -- show current mode.",
           :format => "format <on|off>\nSet xhtml formatting on or off."}

def load_config
  YAML.load File.new('config.yaml')
end

CONFIG = load_config


class User

  def initialize(im, to, methods=[], functions=[])
    @im, @to, @methods, @functions = im, to, methods, functions
  end

  def deliver(text, xhtml)
    xhtml = nil unless @use_xhtml
    x = xhtml.nil? ? nil : gen_xhtml(xhtml)
    @im.deliver @to, text, :chat, x
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
    @handler.remove_stranger @to
    @handler.add_user @to, false
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


class Registered < User

  def initialize(im, to, welcome = true)
    @mode       = CONFIG['default']['mode'].to_sym
    @use_xhtml  = CONFIG['default']['use xhtml']
    @use_status = CONFIG['default']['use status']
    puts "* add user "+to.to_s
    m = [:on,:off,:list,:help,:ping,:test,:easteregg]
    f = [:man,:login,:add,:remove,:mode,:format,:status]
    super im, to, m, f
    plain = "Welcome to #{CONFIG['name']}! Type help for overview. Current mode is #{@mode.to_s}."
    xhtml = "Welcome to <i>#{CONFIG['name']}</i>! Type <b>help</b> for overview. Current mode is <b>#{@mode.to_s}</b>."
    deliver plain, xhtml if welcome
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
    deliver "not yet implemented.", nil
  end

  def on
    deliver "not yet implemented.", nil
  end

  def off
    deliver "not yet implemented.", nil
  end

  def add(feed)
    deliver "not yet implemented.", nil
  end

  def remove(feed)
    deliver "not yet implemented.", nil
  end

  def login(jid) # why does it not working? :(
    jid = "#{jid}@superfeedr.com" unless jid.index('@')
    deliver "try to login to "+jid, nil

    msg = Jabber::Message.new @to
    x = Jabber::Dataforms::XData.new
    f = Jabber::Dataforms::XDataField.new
    f.label= "password"
    f.type= :text_private
    x.type= :form
    x.add f
    msg.add x
    p msg.to_s
    @im.send! msg
  end

  def mode(m="?")
    e = false
    case m
      when "?"     then e=true;deliver "current mode is "+@mode.to_s, "current mode is <b>#{@mode.to_s}</b>"
      when "title" then @mode = :title
      when "all"   then @mode = :all
      else e=true;deliver "mode #{m} not found.", "mode <b>#{m}</b> not found."
    end
    deliver "set mode to " + m, "set mode to <b>#{m}</b>" unless e
  end

  def format(f="?")
    e, s = false, @use_xhtml&&"on"||!@use_xhtml&&"off"
    case f
      when "?"   then e=true;deliver "current formatting is "+s, "current formatting is <b>#{s}</b>"
      when "off" then @use_xhtml = false
      when "on"  then @use_xhtml = true
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

  def notify(event)
    p "here too"
    begin
      event.elements["items"].items.each do |item|
        item.entries.each do |entry|
          unless entry.to_s.strip.empty?
            a, b, syms = {}, {}, [:title,:published,:content,:summary]
            syms.each { |sym| a[sym] = entry.elements[sym.to_s].nil? ? "" : entry.elements[sym.to_s].text.to_s }
            a[:author] = entry.elements["author"].nil? ? "unknown" : entry.elements["author"].elements["name"].text.to_s
            a[:link] = entry.elements["link"].nil? ? "empty" : entry.elements["link"].attributes["href"].to_s
            a[:published] = Time.parse(a[:published]).to_s unless a[:published].empty?
            a[:content] = a[:summary] if a[:content].empty?
            xcontent = a[:content].empty? ? "" : '<br/>'+a[:content].gsub("&", "&amp;")

            a.each {|key, value| b[key] = value.gsub("&", "&amp;") }
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
      end
      if @use_status
        status = event.elements["status"]
        title = status.elements["title"].text.to_s
        feed = status.attributes["feed"].to_s
        nextf = status.elements["next_fetch"].text.to_s
        fetch = status.elements["http"].text.to_s
        code = status.elements["http"].attributes["code"].to_s

        diff, nextf = Time.parse(nextf) - Time.now(), Time.parse(nextf).to_s
        h, m, s = diff.div(3600), diff.div(60), "%.2f" % (diff % 60)
        time = [ (h.zero? ? nil : "#{h}h"), (m.zero? ? nil : "#{m}m"), "#{s}s"].compact.join " "
        deliver "[#{code}] #{title}\n#{fetch}. Next fetch in #{time} (#{nextf}).  [ #{feed} ]","<span style='font-size: small;'>[#{code}] #{title}<br/>#{fetch}. Next fetch in <b>#{time}</b> (#{nextf}).  <i>[ <a href='#{feed}'>#{feed}</a> ]</i></span>"
      end
    rescue Exception => e
      deliver "errör: "+e.to_s, nil
    end
  end

end

