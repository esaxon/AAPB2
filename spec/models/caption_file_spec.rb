require 'rails_helper'
require 'webmock'

describe CaptionFile do
  before :all do
    # WebMock is disabled by defafult, but we use it for these tests.
    # Note that it is re-disable in an :after hook below.
    WebMock.enable!
  end

  let(:id) { 'cpb-aacip-111-02c8693q' }
  let(:srt_example_1) { File.read('./spec/fixtures/captions/srt/example_1.srt') }
  let(:vtt_example_1) { File.read('./spec/fixtures/captions/web_vtt/example_1.vtt') }
  let(:html_example_1) { File.read('./spec/fixtures/captions/html/example_1.html') }
  let(:subject) { CaptionFile.new(id) }

  before do
    # Stub requests so we don't actually have to fetch them remotely. But note
    # that this requires that the files have been pulled down and saved in
    # ./spec/fixtures/srt/ with the same filename they have in S3.
    WebMock.stub_request(:get, CaptionFile.srt_url(id)).to_return(body: srt_example_1)
  end

  describe '#srt' do
    it 'returns the SRT formatted caption retrieved from remote_url' do
      expect(subject.srt).to eq srt_example_1
    end
  end

  describe '#vtt' do
    it 'returns the captions formatted as WebVTT' do
      expect(subject.vtt).to eq vtt_example_1
    end
  end

  describe '#html' do
    it 'returns the captions formatted as HTML' do
      expect(subject.html).to eq html_example_1
    end
  end

  ###
  # Class method tests
  ###

  describe '.srt_filename' do
    it 'returns the filename based on the ID' do
      expect(CaptionFile.srt_filename('foo')).to eq 'foo.srt1.srt'
    end
  end

  describe '.srt_url' do
    it 'returns the URL to the remote SRT caption file' do
      expect(CaptionFile.srt_url('foo')).to eq 'https://s3.amazonaws.com/americanarchive.org/captions/foo/foo.srt1.srt'
    end
  end

  describe 'catalog index displays highlighted captions in results' do

    let(:pb_core_document) {PBCore.new(File.read('spec/fixtures/pbcore/clean-has-captions.xml'))}
    let(:srt_example) {File.read('./spec/fixtures/captions/srt/5678.srt1.srt')}

    let(:query_with_punctuation) {'president, eisenhower: .;'}
    let(:query_with_stopwords) {'the president eisenhower stopworda '}
    let(:test_array) {['PRESIDENT', 'EISENHOWER']}

    let(:caption_query_one) {['LITTLE','ROCK']}
    let(:caption_query_two) {['101ST', 'AIRBORNE']}

    before do
      # Stub requests so we don't actually have to fetch them remotely. But note
      # that this requires that the files have been pulled down and saved in
      # ./spec/fixtures/srt/ with the same filename they have in S3.
      WebMock.stub_request(:get, CaptionFile.srt_url(pb_core_document.id)).to_return(body: srt_example)
    end

    xit 'removes punctuation from and capitalizes the user query' do
      expect(PBCore.clean_query_for_captions(query_with_punctuation)).to eq(test_array)
    end

    xit 'uses stopwords.txt to remove words not used in actual search' do
      expect(PBCore.clean_query_for_captions(query_with_stopwords)).to eq(test_array)
    end

    xit 'returns the caption from the beginning if query word is within first 200 characters' do
      caption = pb_core_document.captions_from_query(caption_query_one)

      # .first returns the preceding '...'
      expect(caption.split[1]).to eq('male')
    end

    xit 'truncates the begging of the caption if keyord is not within first 200 characters' do
      caption = pb_core_document.captions_from_query(caption_query_two)

      # .first returns the preceding '...'
      expect(caption.split[1]).to eq('PUZZLING')
    end
  end


  after(:all) do
    # Re-disable WebMock so other tests can use actual connections.
    WebMock.disable!
  end
end
