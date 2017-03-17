require "rails_helper"

describe SimpleScheduler::At, type: :model do
  describe "AT_PATTERN" do
    let(:pattern) { SimpleScheduler::At::AT_PATTERN }

    it "matches valid times" do
      match = pattern.match("0:00")
      expect(match[2]).to eq("0")
      expect(match[3]).to eq("00")

      match = pattern.match("9:30")
      expect(match[2]).to eq("9")
      expect(match[3]).to eq("30")

      match = pattern.match("Sat 23:59")
      expect(match[2]).to eq("23")
      expect(match[3]).to eq("59")

      match = pattern.match("Sun 00:00")
      expect(match[2]).to eq("00")
      expect(match[3]).to eq("00")
    end

    it "doesn't match invalid times" do
      expect(pattern.match("99:99")).to eq(nil)
      expect(pattern.match("0:60")).to eq(nil)
      expect(pattern.match("12:0")).to eq(nil)
      expect(pattern.match("24:00")).to eq(nil)
      expect(pattern.match("*:60")).to eq(nil)
      expect(pattern.match("Sun 00:60")).to eq(nil)
    end
  end

  describe "when the run :at time includes a specific hour" do
    let(:at) { described_class.new("2:30", ActiveSupport::TimeZone.new("America/Chicago")) }

    context "when the :at hour is after the current time's hour" do
      it "returns the :at hour:minutes on the current day" do
        travel_to Time.parse("2016-12-02 1:23:45 CST") do
          expect(at).to eq(Time.parse("2016-12-02 2:30:00 CST"))
        end
      end
    end

    context "when the :at hour is before the current time's hour" do
      it "returns the :at hour:minutes on the next day" do
        travel_to Time.parse("2016-12-02 3:45:12 CST") do
          expect(at).to eq(Time.parse("2016-12-03 2:30:00 CST"))
        end
      end
    end

    context "when the :at hour is the same as the current time's hour" do
      it "returns the :at hour:minutes on the next day if the :at minute < current time's min" do
        travel_to Time.parse("2016-12-02 2:34:56 CST") do
          expect(at).to eq(Time.parse("2016-12-03 2:30:00 CST"))
        end
      end

      it "returns the :at hour:minutes on the current day if the :at minute > current time's min" do
        travel_to Time.parse("2016-12-02 2:20:00 CST") do
          expect(at).to eq(Time.parse("2016-12-02 2:30:00 CST"))
        end
      end

      it "returns the :at hour:minutes without seconds on the current day if the :at minute == current time's min" do
        travel_to Time.parse("2016-12-02 2:30:30 CST") do
          expect(at).to eq(Time.parse("2016-12-02 2:30:00 CST"))
        end
      end
    end
  end

  describe "when a specific day of the week is given" do
    let(:at) { described_class.new("Fri 23:45", ActiveSupport::TimeZone.new("America/Chicago")) }

    context "if the current day is earlier in the week than the :at day" do
      it "returns the next day the :at day occurs" do
        travel_to Time.parse("2016-12-01 1:23:45 CST") do # Dec 1 is Thursday
          expect(at).to eq(Time.parse("2016-12-02 23:45:00 CST"))
        end
      end
    end

    context "if the current day is later in the week than the :at day" do
      it "returns the next day the :at day occurs, which will be next week" do
        travel_to Time.parse("2016-12-03 1:23:45 CST") do # Dec 3 is Saturday
          expect(at).to eq(Time.parse("2016-12-09 23:45:00 CST"))
        end
      end
    end

    context "if the current day is the same as the :at day" do
      it "returns the current day if :at time is later than the current time" do
        travel_to Time.parse("2016-12-02 23:20:00 CST") do # Dec 2 is Friday
          expect(at).to eq(Time.parse("2016-12-02 23:45:00 CST"))
        end
      end

      it "returns next week's day if :at time is earlier than the current time" do
        travel_to Time.parse("2016-12-02 23:50:00 CST") do # Dec 2 is Friday
          expect(at).to eq(Time.parse("2016-12-09 23:45:00 CST"))
        end
      end

      it "returns the current time without seconds if :at time matches the current time" do
        travel_to Time.parse("2016-12-02 23:45:45 CST") do # Dec 2 is Friday
          expect(at).to eq(Time.parse("2016-12-02 23:45:00 CST"))
        end
      end
    end
  end

  describe "when the run :at time allows any hour" do
    let(:at) { described_class.new("*:30", ActiveSupport::TimeZone.new("America/New_York")) }

    context "when the :at minute < current time's min" do
      it "returns the next hour with the :at minutes on the current day" do
        travel_to Time.parse("2016-12-02 2:45:00 EST") do
          expect(at).to eq(Time.parse("2016-12-02 3:30:00 EST"))
        end
      end
    end

    context "when the :at minute > current time's min" do
      it "returns the current hour with the :at minutes on the current day" do
        travel_to Time.parse("2016-12-02 2:25:25 EST") do
          expect(at).to eq(Time.parse("2016-12-02 2:30:00 EST"))
        end
      end
    end

    context "when the :at minute == current time's min" do
      it "returns the current time without seconds" do
        travel_to Time.parse("2016-12-02 2:30:25 EST") do
          expect(at).to eq(Time.parse("2016-12-02 2:30:00 EST"))
        end
      end
    end
  end

  describe "when the run :at time isn't given" do
    let(:at) { described_class.new(nil, ActiveSupport::TimeZone.new("America/New_York")) }

    it "returns the current time, but drops the seconds" do
      travel_to Time.parse("2016-12-02 1:23:45 PST") do
        expect(at).to eq(Time.parse("2016-12-02 1:23:00 PST"))
      end
    end
  end

  describe "when the run :at time is invalid" do
    it "raises an InvalidAtTime error" do
      expect do
        described_class.new("24:00", ActiveSupport::TimeZone.new("America/New_York"))
      end.to raise_error(SimpleScheduler::At::InvalidTime, "The `at` option '24:00' is invalid.")
    end
  end
end
