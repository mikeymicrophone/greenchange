require File.dirname(__FILE__) + '/../spec_helper'

describe "Collection" do

  before do
    @collection = Collection.new 
    @collection.save!
  end

  describe "collectibles behavior" do
    it "has a set of collectables" do
      @collection.collectables.should be_empty
    end

    it "can add a page to a collection" do
      @collection.collectables << (p = create_page)
      @collection.collectables.should include(p)
    end
    
    it "can remove a page from a collection" do
      @collection.collectables << (p = create_page)
      @collection.collectables.delete(p)
      @collection.collectables.should_not include(p)
    end

    it "can add an asset to a collection" do
      @collection.collectables << (p = create_valid_asset)
      @collection.collectables.should include(p)
      
    end

    it "accepts additions with <<" do
      @collection << (p = create_valid_asset )
      @collection.collectables.should include(p)
      
    end

    it "tests for inclusion with include?" do
      @collection.collectables << (p = create_valid_asset)
      @collection.should include(p)
    end
  end

end
