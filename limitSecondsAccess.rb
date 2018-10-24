# Definition
#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'time'
require 'fileutils'
require 'cgi'
require 'json'

def limitScondsAccess

    begin
        # Init
        ## Access Timestamp Build
        time = Time.now
        sec_timestamp = time.to_i
        sec_usec_timestamp_string = "%10.6f" % time.to_f
        sec_usec_timestamp = sec_usec_timestamp_string.to_f

        ## Access Limit Default Value
        ### Depends on Specifications: For Example 10
        access_limit = 10

        ## Roots Build
        ### Depends on Environment: For Example '/tmp'
        tmp_root = '/tmp'
        access_root = tmp_root + '/access'

        ## Auth Key
        ### Depends on Specifications: For Example 'app_id'
        auth_key = 'app_id'

        ## Response Content-Type
        ### Depends on Specifications: For Example JSON and UTF-8
        response_content_type = 'application/json'
        response_charset = 'utf-8'

        ## Response Bodies Build
        ### Depends on Design
        response_bodies = {}

        # Authorized Key Check
        cgi = CGI.new
        if ! cgi.has_key?(auth_key) then
            raise 'Unauthorized:401'
        end
        auth_id = cgi[auth_key]

        # The Auth Root Build
        auth_root = access_root + '/' + auth_id

        # The Auth Root Check
        if ! FileTest::directory?(auth_root) then
            # The Auth Root Creation
            if ! FileUtils.mkdir_p(auth_root, :mode => 0775) then
                raise 'Could not create the auth root. ' + auth_root + ':500'
            end
        end

        # A Access File Creation Using Micro Timestamp
        ## For example, other data resources such as memory cache or RDB transaction.
        ## In the case of this sample code, it is lightweight because it does not require file locking and transaction processing.
        ## However, in the case of a cluster configuration, file system synchronization is required.
        access_file_path = auth_root + '/' + sec_usec_timestamp.to_s
        if ! FileUtils::touch(access_file_path) then
            raise 'Could not create the access file. ' + access_file_path + ':500'
        end

        # The Access Counts Check
        access_counts = 0
        Dir.glob(auth_root + '/*') do |access_file_path|

            # Not File Type
            if ! FileTest::file?(access_file_path) then
                next
            end

            # The File Path to The Base Name
            base_name = File.basename(access_file_path)

            # The Base Name to Integer Data Type
            base_name_sec_timestamp = base_name.to_i

            # Same Seconds Timestamp
            if sec_timestamp == base_name_sec_timestamp then

                ### The Base Name to Float Data Type
                base_name_sec_usec_timestamp = base_name.to_f

                ### A Overtaken Processing
                if sec_usec_timestamp < base_name_sec_usec_timestamp then
                    next
                end

                ### Access Counts Increment
                access_counts += 1

                ### Too Many Requests
                if access_counts > access_limit then
                    raise 'Too Many Requests:429'
                end

                next
            end

            # Past Access Files Garbage Collection
            if sec_timestamp > base_name_sec_timestamp then
                File.unlink access_file_path
            end
        end

        # The Response Feed
        cgi.out({
            ## Response Headers Feed
            'type' => 'text/html',
            'charset' => response_charset,
        }) {
            ## The Response Body Feed
            ''
        }

    rescue => e
        # Exception to HTTP Status Code
        messages = e.message.split(':')
        http_status = messages[0]
        http_code = messages[1]

        # 4xx
        if http_code >= '400' && http_code <= '499' then
            # logging
            ## snip...
        # 5xx
        elsif http_code >= '500' then
            # logging
            ## snip...

            # The Exception Message to HTTP Status
            http_status = 'foo'
        else
            # Logging
            ## snip...

            # HTTP Status Code for The Response
            http_status = 'Internal Server Error'
            http_code = '500'
        end

        # The Response Body Build
        response_bodies['message'] = http_status
        response_body = JSON.generate(response_bodies)

        # The Response Feed
        cgi.out({
            ## Response Headers Feed
            'status' => http_code + ' ' + http_status,
            'type' => response_content_type,
            'charset' => response_charset,
        }) {
            ## The Response Body Feed
            response_body
        }
    end
end

limitScondsAccess
