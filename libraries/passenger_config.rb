module PassengerRbenvConfig
  def self.set_passenger_config(node)
    prefix = "#{node[:rbenv][:root_path]}/versions/#{node['rbenv']['passenger']['gem_ruby']}"
    passenger_version = node['rbenv']['passenger']['version']
    paths = `#{prefix}/bin/ruby -e '
      begin
        gem "passenger", "#{passenger_version}"
        require "phusion_passenger"
        PhusionPassenger.locate_directories
        puts PhusionPassenger.apache2_module_path
        puts PhusionPassenger.source_root
      rescue Exception
        nil
      end
    '`.each_line.to_a.map &:chomp!
    node.set['rbenv']['passenger']['module_path'] = paths[0]
    node.set['rbenv']['passenger']['root_path'] = paths[1]
  end
end
