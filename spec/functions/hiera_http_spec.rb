require 'spec_helper'
  
require 'puppet/functions/hiera_http'

describe FakeFunction do

  let(:function) { described_class.new }
  before(:each) do
    @lookuphttp = instance_double("LookupHttp")
    @context = instance_double("Puppet::LookupContext")
    allow(LookupHttp).to receive(:new).and_return(@lookuphttp)
    allow(@context).to receive(:cache_has_key)
    allow(@context).to receive(:explain)
    allow(@context).to receive(:interpolate)
    allow(@context).to receive(:cache)
    allow(@context).to receive(:not_found)
  end

  describe "#lookup_key" do

    context "Should run" do
      let(:options) { {
        'uri' => 'http://192.168.0.1:8080/foo/bar'
      } }

      it "should run" do
        expect(LookupHttp).to receive(:new).with({ :host => '192.168.0.1', :port => 8080 })
        expect(@lookuphttp).to receive(:get_parsed).with('/foo/bar').and_return('value')
        expect(@context).to receive(:interpolate).with('/foo/bar').and_return('/foo/bar')
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
    end
      
      
  end


end
