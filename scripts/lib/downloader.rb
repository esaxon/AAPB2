require 'open-uri'
require 'rexml/xpath'
require 'rexml/document'
require 'set'

class Downloader
  KEY = 'b5f3288f3c6b6274c3455ec16a2bb67a'
  # From docs at https://github.com/avpreserve/AMS/blob/master/documentation/ams-web-services.md
  # ie, this not sensitive.

  def initialize(since) # rubocop:disable PerceivedComplexity, CyclomaticComplexity
    @since = since
    since.match(/(\d{4})(\d{2})(\d{2})/).tap do |match|
      fail("Expected YYYYMMDD, not '#{since}'") unless
        match &&
        match[1].to_i < 3000 &&
        match[2].to_i.instance_eval { |m| (1 <= m) && (m <= 12) } &&
        match[3].to_i.instance_eval { |d| (1 <= d) && (d <= 31) }
    end
    @log = File.basename($PROGRAM_NAME) == 'rspec' ? [] : STDOUT
  end

  def self.download_to_directory_and_link(args={})
    fail("Unexpected keys: #{args}") unless Set.new(args.keys).subset?(Set[:days, :page, :ids])
    fail("ids is exclusive") if args[:ids] && args.keys.size > 1
    now = Time.now.strftime('%F_%T')
    if args[:ids]
      self.mkdir_and_cd("#{now}_by_ids_#{args[:ids].size}")
      args[:ids].each do |id|
        short_id = id.sub(/.*[_\/]/, '')
        url = "https://ams.americanarchive.org/xml/pbcore/key/#{KEY}/guid/#{short_id}"
        content = URI.parse(url).read(read_timeout: 240)
        File.write("#{short_id}.pbcore", content)
      end
    else
      args[:page] ||= 1 # API is 1-indexed, but also returns page 1 results for page 0.
      since = if args[:days]
                (Time.now - args[:days] * 24 * 60 * 60).strftime('%Y%m%d')
              else
                '20000101' # ie, beginning of time.
              end
      self.mkdir_and_cd("#{now}_since_#{since}_starting_page_#{args[:page]}")
      downloader = Downloader.new(since)
      downloader.download_to_directory(args[:page])
    end
    Dir.pwd
  end
  
  def self.mkdir_and_cd(name)
    Dir.chdir(File.dirname(File.dirname(File.dirname(__FILE__))))
    path = ['tmp', 'pbcore', 'download', name]
    path.each do |dir|
      begin
        Dir.mkdir(dir)
      rescue
        nil # may already exist
      end
      Dir.chdir(dir)
    end

    Dir.chdir('..')
    link_name = 'LATEST'
    File.unlink(link_name) if File.symlink?(link_name)
    fail "Did not expect '#{link_name}'" if File.exist?(link_name)
    File.symlink(path.last, link_name)

    Dir.chdir(link_name)
  end

  def download_to_directory(start_page)
    download(start_page) do |collection, page|
      name = "page-#{page}.pbcore"
      File.write(name, collection)
      @log << "#{Time.now}\tWrote #{name}\n"
    end
  end

  def download(page)
    loop do
      url = "https://ams.americanarchive.org/xml/pbcore/key/#{KEY}/modified_date/#{@since}/page/#{page}"
      content = nil
      until content
        begin
          @log << "#{Time.now}\tTrying #{url}\n"
          content = URI.parse(url).read(read_timeout: 240)
        rescue Net::ReadTimeout
          @log << "#{Time.now}\tTimeout. Retrying in 10...\n"
          sleep 10
        end
      end
      if content =~ /^<error>/
        @log << "#{Time.now}\tPaged past end of results: page #{page}\n"
        return
      else
        @log << "#{Time.now}\tGot page #{page}\n"
        yield(content, page)
        page += 1
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  abort 'No args' unless ARGV.empty?
  Downloader.download_to_directory_and_link
end
