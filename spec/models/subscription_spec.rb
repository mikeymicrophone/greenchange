require File.dirname(__FILE__) + '/../spec_helper'

describe Subscription do
  before do
    @test_url = 'http://test.org'
    @atom_url = 'http://test_atom.org'
    @sub = new_subscription :url => @test_url
  end

  it "records the last time it was updated" do
    time = Time.now
    Time.stub!(:now).and_return time
    @sub.update!
    @sub.last_updated_at.should == time
  end

  it "pulls the feed on create" do
    @sub.stub!(:valid_url).and_return true
    @sub.should_receive(:fetch)
    @sub.save
  end

  it "validates the format of the url" do
    @sub.url = "invalid host . com"
    @sub.should_not be_valid
  end

  describe "with valid url" do
    before do
      @sub.stub!(:valid_url).and_return true
      @sub.stub!(:open).with(@test_url).and_return File.read("#{RAILS_ROOT}/spec/fixtures/rss_20.rss")
      @sub.stub!(:open).with(@atom_url).and_return File.read("#{RAILS_ROOT}/spec/fixtures/atom_10.xml")
    end

    it "gets input from open-uri" do
      @sub.should_receive(:open).and_return File.read("#{RAILS_ROOT}/spec/fixtures/rss_20.rss")
      @sub.fetch
    end

    it "only returns items that are new since the last update" do
      @sub.last_updated_at = Time.mktime 2008, 8, 6
      @sub.fetch.all? {|entry| entry.last_updated > @sub.last_updated_at}.should be_true
    end

    it "fetched feed create new reposts" do
      @sub.reposts.should_receive :create
      @sub.save!
    end

    it "builds valid reposts" do
      @entries = @sub.fetch
      @sub.reposts.build_from_feed(@entries)
      @sub.reposts.first.should be_valid
    end

    describe "repost metadata" do
      before do
        @entry = @sub.entries.first
        @sub.reposts.build_from_feed(@sub.fetch)
        @sub.save
        @sub.last_updated_at = nil
      end
      it "sets repost creator" do
        @sub.reposts.create_from_feed([@entry]).first.data.creator.should == @entry.author
      end

      it "sets repost creator_url" do
        pending "creator urls spottingz :)"
        @sub.reposts.translate(@entry).data.creator_url.should == @sub.fetch.first.helloze?
      end
      it "sets repost source" do
        @sub.reposts.first.data.source.should == @sub.feed.title
      end
      it "sets repost source_url" do
        @sub.reposts.first.data.source_url.should == @sub.fetch.first.url
      end
      it "sets repost published_at" do
        @sub.reposts.first.data.published_at.should == @sub.fetch.first.date_published
      end
    end

    it "parses atom feeds" do
      @sub.url = @atom_url
      @sub.fetch.should_not be_empty
    end

    it "should send etags and ifnotmodiedsince headers or something"

  end
end