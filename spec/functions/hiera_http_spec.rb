require 'spec_helper'
  
module Puppet
  class LookupContext
  end
end


describe 'hiera_http' do

  let(:options) {
    {
      'host' => '10.9.8.7',
      'port' => '8080',
    }
  }

  it { 
     is_expected.to raise_error { } 
     is_expected.to run.with_params('foo', options, {}) }
end
