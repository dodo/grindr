require 'time'


class Entry
  attr_reader :title, :authors, :links, :published, :content,
    :xtitle, :xauthors, :xlinks, :xpublished, :xcontent # xhtml-containing attrs
  def initialize(stanza)
    #plain
    @title     = stanza.title
    @published = stanza.published.to_s
    @authors   = generate_authors stanza
    @links     = generate_links   stanza
    @content   = generate_content stanza
    #xhtml
    @xtitle     = @title
    @xpublished = @published
    @xauthors   = @authors
    @xlinks     = generate_xhtml_links   stanza
    @xcontent   = generate_xhtml_content stanza
  end
  private
  def generate_authors(stanza)
    stanza.authors.empty? ? "unknown" : stanza.authors.map{|a|a.name}.join(", ")
  end
  private
  def generate_links(stanza)
    links = stanza.links
    links.empty? ? "empty" : links.map{|l|"#{l.title} [ #{l.href} ]"}.join(", ")
  end
  private
  def generate_content(stanza)
    stanza.summary # BUG FIXME filter xhtml-im malformed stuff out (eg links)
  end
  private
  def generate_xhtml_links(stanza)
    links = stanza.links
    unless links.empty?
      result = links.map{ |l| "<a href='#{l.href}'>#{l.title}</a>" }.join ", "
    else
      result = "empty"
    end
    result
  end
  private
  def generate_xhtml_content(stanza)
    # not pretty but works :/
    rexps = [ /&(?!#?[\w-]+;)/u, /</u, />/u, /"/u, /'/u, /\r/u ]
    subs  = ['&amp;', '&lt;', '&gt;', '&quot;', '&apos;', '&#13;']
    content = stanza.summary.clone
    unless content.empty? 
      rexps.zip(subs).each { |r,s| content = content.gsub r, s } # FIXME replace <a>-links with 'title [ href ]'
      content = "<br/>#{content}"
    end
    content
  end
end


class Notification
  attr_reader :feed_title, :feed_url, :next_fetch, :message_status,
    :http_status, :entries, :time_left
  def initialize(stanza)
    @feed_title    = "notification.title" # BUG FIXME stanza.title
    @feed_url      = stanza.feed_url
    @next_fetch    = stanza.next_fetch
    @message_status = stanza.message_status
    @http_status   = stanza.http_status
    @entries = []

    stanza.entries.each { |entry| @entries << Entry.new(entry) }
    @message_status << '.' unless @message_status.end_with? '.'
    @time_left  = generate_time_left
    @next_fetch = @next_fetch.to_s
  end
  private
  def generate_time_left
    diff = @next_fetch - Time.now()
    h, m, s = diff.div(3600), diff.div(60), "%.2f" % (diff % 60)
    [(h.zero? ? nil: "#{h}h"),(m.zero? ? nil: "#{m}m"),"#{s}s"].compact.join " "
  end
end



def parse(stanza)
  Notification.new stanza
end
