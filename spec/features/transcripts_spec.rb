require 'rails_helper'
require_relative '../../scripts/lib/pb_core_ingester'

describe 'Transcripts' do
  #  include ValidationHelper

  before(:all) do
    PBCoreIngester.load_fixtures
  end

  # xit due to fact we re-organized Captions and Transcripts
  describe '#show' do
    xit 'renders SRT as HTML' do
      visit '/transcripts/1234'
      expect(page).to have_text('Raw bytes 0-255 follow')
    end
  end
end
