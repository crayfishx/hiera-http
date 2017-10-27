require 'spec_helper'
  
require 'puppet/functions/hiera_http'

describe FakeFunction do

  let(:function) { described_class.new }
  before(:each) do
    @lookuphttp = instance_double("LookupHttp")
    @context = instance_double("Puppet::LookupContext")
    allow(LookupHttp).to receive(:new).and_return(@lookuphttp)
    allow(@lookuphttp).to receive(:get_parsed).and_return('value')
    allow(@context).to receive(:cache_has_key)
    allow(@context).to receive(:explain)
    allow(@context).to receive(:interpolate)
    allow(@context).to receive(:cache)
    allow(@context).to receive(:not_found)
    allow(@context).to receive(:interpolate).with('/path').and_return('/path')
  end

  describe "#lookup_key" do

    context "Should run" do
      let(:options) { {
        'uri' => 'http://192.168.0.1:8080/path'
      } }

      it "should run" do
        expect(LookupHttp).to receive(:new).with({ :host => '192.168.0.1', :port => 8080 })
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return('value')
        expect(function.lookup_key('bar', options, @context)).to eq('value')
      end
    end

    context "When using __XXX__ interpolation" do
      let(:key) { 'foo::bar::tango' }
       
      it "should interpolate __KEY__ correctly" do
        options = { 'uri' => 'http://localhost/path/__KEY__' }
        expect(@context).to receive(:interpolate).with('/path/foo::bar::tango').and_return('/path/foo::bar::tango')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/foo::bar::tango')
        function.lookup_key('foo::bar::tango', options, @context)
      end

      it "should interpolate __MODULE__ correctly" do
        options = { 'uri' => 'http://localhost/path/__MODULE__' }
        expect(@context).to receive(:interpolate).with('/path/foo').and_return('/path/foo')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/foo')
        function.lookup_key('foo::bar::tango', options, @context)
      end

      it "should interpolate __CLASS__ correctly" do
        options = { 'uri' => 'http://localhost/path/__CLASS__' }
        expect(@context).to receive(:interpolate).with('/path/foo::bar').and_return('/path/foo::bar')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/foo::bar')
        function.lookup_key('foo::bar::tango', options, @context)
      end

      it "should interpolate __PARAMETER__ correctly" do
        options = { 'uri' => 'http://localhost/path/__PARAMETER__' }
        expect(@context).to receive(:interpolate).with('/path/tango').and_return('/path/tango')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/tango')
        function.lookup_key('foo::bar::tango', options, @context)
      end

      it "should interpolate more than one field" do
        options = { 'uri' => 'http://localhost/path/__MODULE__/__PARAMETER__/__PARAMETER__' }
        expect(@context).to receive(:interpolate).with('/path/foo/tango/tango').and_return('/path/foo/tango/tango')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/foo/tango/tango')
        function.lookup_key('foo::bar::tango', options, @context)
      end


    end

    context "When confine_to_keys is set" do
      let(:options) { {
        'uri' => 'http://localhost/path',
        'confine_to_keys' => [ /^tango.*/ ],
      } }

      before(:each) do
        allow(@context).to receive(:interpolate).with('/path').and_return('/path')
      end

      it "should return not found for non matching keys" do
        expect(@context).to receive(:not_found)
        expect(@lookuphttp).not_to receive(:get_parsed)
        function.lookup_key('bar', options, @context)
      end

      it "should run if key matches" do
        expect(@context).not_to receive(:not_found)
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return('value')
        expect(function.lookup_key('tangodelta', options, @context)).to eq('value')
      end
    end

    context "Output of lookup_http" do
      let(:options) { {
        'uri' => 'http://localhost/path',
        'output' => 'json'
      } }
      it "should dig if the value is a hash" do
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return({ 'tango' => 'delta' })
        expect(function.lookup_key('tango', options, @context)).to eq('delta')
      end
      it "should return the whole value if the value is a string" do
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return('delta')
        expect(function.lookup_key('tango', options, @context)).to eq('delta')
      end
    end

    context "cached values" do
      let(:options) { {
        'uri' => 'http://localhost/path',
      } }

      it "should use a cached lookuphttp object when available" do
        expect(@context).to receive(:cache_has_key).with('__lookuphttp').and_return(true)
        expect(LookupHttp).not_to receive(:new)
        expect(@context).to receive(:cached_value).with('__lookuphttp').and_return(@lookuphttp)
        expect(@lookuphttp).to receive(:get_parsed).and_return({ 'tango' => 'bar'})
        expect(function.lookup_key('tango', options, @context)).to eq('bar')
      end


      it "should create a new lookuphttp object when not cached" do
        expect(@context).to receive(:cache_has_key).with('__lookuphttp').and_return(false)
        expect(LookupHttp).to receive(:new).and_return(@lookuphttp)
        expect(@context).not_to receive(:cached_value).with('__lookuphttp')
        expect(@lookuphttp).to receive(:get_parsed).and_return({ 'tango' => 'bar'})
        expect(function.lookup_key('tango', options, @context)).to eq('bar')
      end


      it "should used cached value when available" do
        expect(@context).to receive(:cache_has_key).with('/path').and_return(true)
        expect(@context).to receive(:cached_value).with('/path').and_return({ 'tango' => 'bar'})
        expect(@lookuphttp).not_to receive(:get_parsed)
        expect(function.lookup_key('tango', options, @context)).to eq('bar')
      end
    end

    context "nil versus undefined" do
      let(:options) { {
        'uri' => 'http://localhost/path',
      } }

      it "should return nil when a value is set to nil" do
        response = { "config" => nil }
        expect(@lookuphttp).to receive(:get_parsed).and_return(response)
        expect(@context).not_to receive(:not_found)
        expect(function.lookup_key('config', options, @context)).to eq(nil)
      end
      it "should return call not_found when the key doesn't exist" do
        response = { "foo" => "bar"  }
        expect(@lookuphttp).to receive(:get_parsed).and_return(response)
        expect(@context).to receive(:not_found)
        expect(function.lookup_key('config', options, @context)).to eq(nil)
      end

      it "should return not_found when a nil value is returned" do
        expect(@lookuphttp).to receive(:get_parsed).and_return(nil)
        expect(@context).to receive(:not_found)
        expect(function.lookup_key('foo', options, @context)).to eq(nil)
      end
    end
        

      

    context "Digging values" do
      let(:options) { {
       'uri' => 'http://localhost/path',
      } }

      let(:response) { {
        "document" => {
          "settings" => {
            "docroot" => "/www"
           }
        }
      } }
      before(:each) do
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return(response)
      end

      it "should default to digging for the lookup key" do
        expect(function.lookup_key('document', options, @context)).to eq({ "settings" => { "docroot" => "/www" } } )
      end

      it "should be able to dig for other keys" do
        extra_opts = { "dig_key" => "document" }
        expect(function.lookup_key('bar', options.merge(extra_opts), @context)).to eq({ "settings" => { "docroot" => "/www" } } )
      end

      it "should dig nested values using the dot notation" do
        extra_opts = { "dig_key" => "document.settings" }
        expect(function.lookup_key('bar', options.merge(extra_opts), @context)).to eq({ "docroot" => "/www" } )
      end

      it "should interpolate tags in the key path" do
        extra_opts = { "dig_key" => "document.__MODULE__.__PARAMETER__" }
        expect(function.lookup_key('settings::docroot', options.merge(extra_opts), @context)).to eq("/www")
      end

      it "should return the whole data structure if dig is disabled" do
        extra_opts = { "dig" => false }
        expect(function.lookup_key('bar', options.merge(extra_opts), @context)).to eq(response)
      end


    end
  end
end
