require 'vmc/client'
require 'json'

module VMC
  module KNIFE
    module JSON_EXPANDER
      
      # Reads the ip of a given interface and the mask
      # defaults on eth0 then on wlan0 and then whatever it can find that is not 127.0.0.1
      def self.ip_auto(interface='eth0')
        ifconfig = File.exist?("/sbin/ifconfig") ? "/sbin/ifconfig" : "ifconfig"
        res=`#{ifconfig} | sed -n '/#{interface}/{n;p;}' | grep 'inet addr:' | grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}' | head -1`
        if interface == 'eth0' && (res.nil? || res.strip.empty?)
          res = ip_auto "wlan0"
          res = res[0] if res
          if res.strip.empty?
            #nevermind fetch the first IP you can find that is not 127.0.0.1
            res=`#{ifconfig} | grep 'inet addr:' | grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}' | head -1`
          end
        end
        res.strip! if res
        unless res.empty?
          # gets the Mask
          line=`#{ifconfig} | grep 'inet addr:#{res}' | awk '{ print $1}' | head -1`
#          puts "parsing ip and mask in line #{line}"
          mask=`#{ifconfig} | grep 'inet addr:#{res}' | grep -v '127.0.0.1' | cut -d: -f4 | awk '{ print $1}' | head -1`
          mask.strip!
#          puts "got ip #{res} and mask #{mask}"
          return [ res, mask ]
        end
      end
      
      # Derive a seed guaranteed unique on the local network  according to the IP.
      def self.ip_seed()
        ip_mask=ip_auto()
        ip = ip_mask[0]
        mask = ip_mask[1]
        ip_segs = ip.split('.')
        if mask.start_with? "255.255.255."
          ip_segs[3]
        elsif mask.start_with? "255.255"
          "#{ip_segs[2]}-#{ip_segs[3]}"
        elsif mask.start_with? "255."
          "#{ip_segs[1]}-#{ip_segs[2]}-#{ip_segs[3]}"
        else
          #hum why are we here?
          "#{ip_segs[0]}-#{ip_segs[1]}-#{ip_segs[2]}-#{ip_segs[3]}"
        end
      end
    
      # Loads a json file.
      # Makes up to 10 passes evaluating ruby in the values that contain #{}.
      def self.expand_json(file_path)
        raise "The file #{file_path} does not exist" unless File.exists? file_path
        data = File.open(file_path, "r") do |infile| JSON.parse infile.read end
        extract_node(data,data)

        data
      end

      def self.extract_node(node, context)
          
        if node.is_a? Hash
          node.each_pair do |key, value|
            extract_node(value, context)
          end
        elsif node.is_a? Array
          node.each do |v|
            extract_node(v, context)
          end
        else
          extract_value(node, context)
        end

      end

      def self.extract_value(value, context)
        if value.is_a? String 
          reg = /\#{([^}]*)}/
          return value unless reg =~ value
          value.gsub!(reg) do |mat|
            extract_value(eval($1, get_binding(context)), context)
          end
        end  
      end

      def self.get_binding(this)
        return binding
      end
      
    end    
  end # end of KNIFE
end
