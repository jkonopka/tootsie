require 'httpclient'
require 's3'

module Tranz
  
  class IncompatibleOutputError < Exception; end
  
  class Output
    
    def initialize(url)
      @url = url
      @temp_file = Tempfile.new('tranz')
      @temp_file.close
      @file_name = @temp_file.path
    end
    
    # Put data into the output. Options:
    #
    # * +:content_type+ - content type of the stored data.
    # * +:s3_access+ - S3 access permissions, one of +private+ (default), +public-read+,
    #     +public-read-write+ or +authenticated-read+.
    # * +:s3_storage_class+ - S3 storage class, either +:reduced_redundancy+ or +:standard+ (default).
    #
    def put!(options = {})
      case @url
        when /^s3:([^\/]+)\/+(.+)$/
          bucket_name, path = $1, $2
          File.open(@temp_file.path, 'r') do |file|
            s3_service = Tranz::Application.get.s3_service
            begin
              bucket = s3_service.buckets.find(bucket_name)
              object = bucket.objects.build(path)
              object.acl = options[:s3_acl] || :private
              object.content_type = @content_type if @content_type
              object.storage_class = options[:s3_storage_class] || :standard
              object.content = file
              object.save
              @result_url = object.url
            rescue ::S3::Error::NoSuchBucket
              raise IncompatibleOutputError, "Bucket #{bucket_name} not found"
            end
          end
        when /^http(s?):\/\//
          File.open(@temp_file.path, 'wb') do |file|
            HTTPClient.new.get_content(@url) do |chunk|
              file << chunk
            end
          end
        else
          raise IncompatibleOutputError, "Don't know to store output URL: #{@url}"
      end
    end
    
    def close
      @temp_file.unlink
    end
    
    attr_reader :url
    attr_reader :result_url
    attr_reader :file_name
    attr_accessor :content_type
    
  end

end