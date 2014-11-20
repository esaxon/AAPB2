require_relative '../../scripts/cleaner'

describe Cleaner do
  
  cleaner = Cleaner.new
  
  Dir['spec/fixtures/pbcore/actual-*.xml'].each do |path_actual|
    it "cleans #{File.basename(path_actual)}" do
      path_clean = path_actual.gsub('actual', 'clean')
      actual = File.read(path_actual)
      clean = File.read(path_clean)

      expect(cleaner.clean(actual)).to eq(clean)
    end
  end
  
end