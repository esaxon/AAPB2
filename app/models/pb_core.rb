require 'rexml/document'
require 'rexml/xpath'
require 'solrizer'

require_relative 'organization'

class PBCore
  def initialize(xml)
    @xml = xml
    @doc = REXML::Document.new xml
  end
  def text
    @text ||= xpaths('/*//*[text()]').map{|s| s.strip}.select{|s| !s.empty?}
  end
  def descriptions
    @descriptions ||= xpaths('/*/pbcoreDescription')
  end
  def genres
    @genres ||= xpaths('/*/pbcoreGenre')
  end
  def subjects
    @subjects ||= xpaths('/*/pbcoreSubject')
  end
  def contributors
    @contributors ||= REXML::XPath.match(@doc, '/pbcoreDescriptionDocument/pbcoreContributors').map{|rexml|
      Contributor.new(rexml)
    }
  end
  def creators
    @creators ||= REXML::XPath.match(@doc, '/pbcoreDescriptionDocument/pbcoreCreators').map{|rexml|
      Creator.new(rexml)
    }
  end
  def publishers
    @contributors ||= REXML::XPath.match(@doc, '/pbcoreDescriptionDocument/pbcoreContributors').map{|rexml|
      Contributor.new(rexml)
    }
  end
  def instantiations
    @instantiations ||= REXML::XPath.match(@doc, '/*/pbcoreInstantiation').map{|rexml|
      Instantiation.new(rexml)
    }
  end
  def rights_summary
    @rights_summary ||= xpath('/*/pbcoreRightsSummary/rightsSummary')
  rescue NoMatchError
    nil
  end
  def asset_type
    @asset_type ||= xpath('/*/pbcoreAssetType') 
  rescue NoMatchError
    nil # We want to distinguish an empty string from no value in source data
  end
  def asset_date
    @asset_date ||= xpath('/*/pbcoreAssetDate')
  rescue NoMatchError
    nil
  end
  def year
    @year ||= asset_date ? asset_date.gsub(/-\d\d-\d\d/,'') : nil
  end
  def contribs
    @contribs ||= 
      # TODO: Cleaner xpath syntax?
      xpaths('/*/pbcoreCreator/creator') +
      xpaths('/*/pbcoreCreator/creator/@affiliation') +
      xpaths('/*/pbcoreContributor/contributor') +
      xpaths('/*/pbcoreContributor/contributor/@affiliation') +
      xpaths('/*/pbcorePublisher/publisher') +
      xpaths('/*/pbcorePublisher/publisher/@affiliation')
  end
  def titles
    @titles ||= xpaths('/*/pbcoreTitle')
  end
  def title
    @title ||= begin
      # TODO: just use xpath, instead of creating intermediate hash.
      # TODO: If a titleType is repeated, we just pick one arbitrarily.
      titles = Hash[
        REXML::XPath.match(@doc, '/pbcoreDescriptionDocument/pbcoreTitle').map { |node|
          [
            REXML::XPath.first(node,'@titleType').value,
            node.text
          ]
        } 
      ]
      # TODO: get the right order: If the best choice is missing, selection might be arbitrary.
      titles['Program'] || titles['Series'] || 
        titles['Episode'] || titles['Album'] ||
        titles['Raw Footage'] || titles['Promo'] ||
        titles['Clip'] || titles['Episode Number'] ||
        titles['Segment'] || titles['Collection'] ||
        titles['Label'] || titles['Uncataloged'] ||
        titles.values.first
    end
  end
  def id
    @id ||= xpath('/*/pbcoreIdentifier[@source="http://americanarchiveinventory.org"]')
  end
  def ids
    @ids ||= xpaths('/*/pbcoreIdentifier')
  end
  def img_src
    # ID may contain a slash, and that's ok.
    @img_src ||= "https://mlamedia01.wgbh.org/aapb/thumnail/#{id}.jpg"
  end
  def organization_pbcore_name
    @organization_pbcore_name ||= xpath('/*/pbcoreAnnotation[@annotationType="organization"]')
  end
  def organization
    @organization ||= Organization.find_by_pbcore_name(organization_pbcore_name)
  end
  def rights_code
    @rights_code ||= xpath('/*/pbcoreRightsSummary/rightsEmbedded/AAPB_RIGHTS_CODE')
  end
  def media_type
    @media_type ||= begin
      media_types = xpaths('/*/pbcoreInstantiation/instantiationMediaType')
      ['Moving Image', 'Sound', 'other'].each {|type|
        return type if media_types.include? type
      }
      return 'other' if media_types == [] # pbcoreInstantiation is not required, and injected it seems heavy.
      raise "Unexpected media types: #{media_types.uniq}"
    end
  end
  def digitized
    @digitized ||= xpaths('/*/pbcoreInstantiation/instantiationGenerations').include?('Proxy') # TODO get the right value
  end

  def to_solr
    # Keep Solr name singular, even if the method is plural:
    # Easier not to need to worry about cardinality.
    {
      'id' => id,
      'xml' => @xml,
      
      # constrained searches:
      'text' => text,
      'title' => titles,
      'contrib' => contribs,
      
      # facets:
      'media_type' => media_type,
      'genre' => genres,
      'year' => year,
      'asset_type' => asset_type,
      'organization' => organization.short_name
    }
  end
  
  private

  class NoMatchError < StandardError
  end
  def xpath(xpath)
    REXML::XPath.match(@doc, xpath).tap do |matches|
      if matches.length != 1
        raise NoMatchError, "Expected 1 match for '#{xpath}'; got #{matches.length}"
      else
        node = matches.first
        return node.respond_to?('text') ? node.text : node.value
      end
    end
  end
  def xpaths(xpath)
    REXML::XPath.match(@doc, xpath).map{|node| node.respond_to?('text') ? node.text : node.value}
  end
  
  module Optionally
    def optional(xpath)
      match = REXML::XPath.match(@rexml, xpath).first
      match ? match.text : nil
    end
  end
  
  class Contributor
    def initialize(rexml)
      @rexml = rexml
    end
    def name
      @name = REXML::XPath.match(@rexml, 'contributor')
    end
    def role
      @role = REXML::XPath.match(@rexml, 'role')
    end
    def affiliation
      @affiliation = REXML::XPath.match(@rexml, 'affiliation')
    end
  end
  class Publisher
    def initialize(rexml)
      @rexml = rexml
    end
  end
  class Creator
    def initialize(rexml)
      @rexml = rexml
    end
  end
  
  class Instantiation
    include Optionally
    def initialize(rexml)
      @rexml = rexml
    end
    def media_type
      @media_type ||= optional('instantiationMediaType')
    end
    def duration
      @duration ||= optional('instantiationDuration')
    end
  end
  
end
