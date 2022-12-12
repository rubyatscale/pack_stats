module PackStats
  RSpec.describe GaugeMetric do
    it 'errors when metric length is greater than 200' do
      expect { GaugeMetric.for('a' * 250, 0, []) }.to raise_error do |e|
        expect(e.message).to eq 'Metrics names must not exceed 200 characters: modularization.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      end
    end

    it 'does not error when metric is less than 100' do
      expect { GaugeMetric.for('a' * 150, 0, []) }.to_not raise_error
    end
  end
end
