require 'spec_helper'

module Muninator
  describe "Template for code lines" do
    include FakeFS::SpecHelpers
    before :each do
      Template.paths << 'app/munin'
      File.open 'app/munin/code.config', 'w' do |f|
        f.puts "graph_label Code\nlines.label Lines\nlines.min <%= 3 - 2 %>"
      end
      File.open 'app/munin/code.fetch', 'w' do |f|
        f.puts "lines.value <%= Muninator.name.length %>"
      end
    end
    it do
      Template.should be_a(Class)
    end

    it "should autodetect files" do
      lambda {
        Template.load_all
      }.should change(Template.list, :count).by(1)
      Template.list.should_not be_empty
      t = Template.list.first
      t.command.should == 'code'
    end

    describe "autodetected code" do

      before :each do
        Template.load_all
        @template = Template.list.first
        @template.should_not be_nil
      end

      it "should provide command" do
        Template.commands.should include('code')
      end

      it "should be findable" do
        Template.find('code').should == @template
      end

      it "should have path to config file" do
        @template.config_path.should =~ %r~app/munin/code.config$~
      end

      it "should have existing config file" do
        File.exists?(@template.config_path).should be_true
      end

      it "should render config" do
        config = @template.config
        config.should_not be_blank
        config.should include('graph_label Code')
        config.should include('lines.label Lines')
        config.should include('lines.min 1')
      end

      it "should have path to fetch file" do
        @template.fetch_path.should =~ %r~app/munin/code.fetch$~
      end

      it "should have existing fetch file" do
        File.exists?(@template.fetch_path).should be_true
      end

      it "should render fetch" do
        data = @template.fetch
        data.should_not be_blank
        data.should include('lines.value 9')
      end
    end
  end
end

