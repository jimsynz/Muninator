require 'spec_helper'

describe "Muninator" do
  before :each do
    Muninator.stub!(
      :config_path => '/tmp/config'
    )
    @config = {
      'production' => {
        'key' => 'value'
      }
    }
    YAML.stub!(:load_file).with('/tmp/config').and_return(@config)
    Rails.stub!(:env => 'production', :root => mock('/tmp/rails', :join => '/tmp/rails/mocked' )  )
  end

  after :each do
    Muninator.clear_config
  end

  it do
    Muninator.should be_a(Module)
  end

  it "should load config for current Rails env" do
    Muninator.should_receive(:config_path).and_return("config_path")
    YAML.should_receive(:load_file).with("config_path").and_return(@config)
    Rails.should_receive(:env).and_return('production')
    Muninator.send :load_config
    Muninator.instance_variable_get('@config').should == @config['production']
  end

  it "should load config only once" do
    YAML.should_receive(:load_file).once.with("/tmp/config").and_return(@config)
    Muninator.send :load_config
    Muninator.send :load_config
  end

  it "should reload config on request" do
    YAML.should_receive(:load_file).twice.with("/tmp/config").and_return(@config)
    Muninator.send :load_config
    Muninator.clear_config
    Muninator.send :load_config
  end

  it "should set restrictions from config file"

  it "should add paths and load config on setup" do
    Rails.root.should_receive(:join).with('app/munin').twice.and_return('/tmp')
    Muninator.should_receive(:load_config)

    Muninator.setup
  end

  describe "booting" do

    it "should register a working progress if running in Passenger" do
      PhusionPassenger = "Passenger" # "load" passenger
      Muninator.stub(:setup => true)
      PhusionPassenger.should_receive(:on_event).with(:starting_worker_process)
      Muninator.boot
      Object.send :remove_const, :PhusionPassenger
    end

    it "should start immediatly without Passenger" do
      Muninator.stub(:setup => true)
      Muninator.should_receive(:start)
      Muninator.boot
    end

  end

  describe "standalone mode" do
    it "should cancel if setting misses in config" do
      lambda {
        Muninator.boot_standalone
      }.should raise_error(Muninator::InvalidConfig)
    end

    it "should run if setting present in config" do
      @config['production']['standalone'] = true
      Muninator.should_receive(:start)
      Muninator.boot_standalone
    end

    it "should be reflected from config" do
      Muninator.should_not be_standalone
      @config['production']['standalone'] = true
      Muninator.should be_standalone
    end

    it "should be enforced if setting present in config" do
      @config['production']['standalone'] = true
      Muninator.should_not_receive(:start)
      lambda {
        Muninator.boot
      }.should raise_error(Muninator::InvalidConfig)
    end
  end
end
