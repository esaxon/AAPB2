require 'rsolr'
require 'date' # NameError deep in Solrizer without this.
require_relative '../../app/models/validated_pb_core'
require_relative 'uncollector'
require_relative 'cleaner'

class PBCoreIngester
  attr_reader :solr

  def initialize(url='http://localhost:8983/solr/')
    @solr = RSolr.connect(url: url) # TODO: read config/solr.yml
    @log = File.basename($PROGRAM_NAME) == 'rspec' ? [] : STDOUT
  end

  # TODO: maybe light session management? If we don't go in that direction, this should just be a module.

  def delete_all
    @solr.delete_by_query('*:*')
    commit
  end

  def ingest(path)
    cleaner = Cleaner.new

    begin
      xml = File.read(path)
    rescue => e
      raise ReadError.new(e)
    end

    @md5s_seen = Set.new

    xml_top = xml[0..100] # just look at the start of the file.
    case xml_top
    when /<pbcoreCollection/
      @log << "#{Time.now}\tRead pbcoreCollection from #{path}\n"
      Uncollector.uncollect_string(xml).each do |document|
        md5 = Digest::MD5.hexdigest(document)
        if @md5s_seen.include?(md5)
          # Documents are often repeated in AMS exports.
          @log << "#{Time.now}\tSkipping already seen\n"
        else
          @md5s_seen.add(md5)
          ingest_xml_no_commit(cleaner.clean(document))
        end
      end
    when /<pbcoreDescriptionDocument/
      ingest_xml_no_commit(cleaner.clean(xml))
    else
      fail ValidationError.new("Neither pbcoreCollection nor pbcoreDocument. #{path}: #{xml_top}")
    end
    begin
      # If collections are ingested, commit after each collection;
      # If individual documents are ingested, still commit after each.
      commit
    rescue => e
      raise SolrError.new(e)
    end
  end

  # TODO: private
  
  def optimize
    @solr.optimize
  end
  def commit
    @solr.commit
  end
  def ingest_xml_no_commit(xml)
    begin
      pbcore = ValidatedPBCore.new(xml)
    rescue => e
      raise ValidationError.new(e)
    end

    begin
      @solr.add(pbcore.to_solr)
    rescue => e
      raise SolrError.new(e)
    end

    @log << "#{Time.now}\tUpdated solr record #{pbcore.id}\n"

    pbcore
  end

  class ChainedError < StandardError
    # Sorry, this is more java-ish than ruby-ish,
    # but downstream I want to distinguish different
    # error types, AND I want to know the root cause.
    # This makes that possible.
    def initialize(e)
      @base_error = e
    end

    def message
      if @base_error.respond_to?(:message)
        @base_error.message + "\n" + @base_error.backtrace[0..2].join("\n") + "\n..."
      else
        @base_error
      end
    end
  end
  class ReadError < ChainedError
  end
  class ValidationError < ChainedError
  end
  class SolrError < ChainedError
  end
end
