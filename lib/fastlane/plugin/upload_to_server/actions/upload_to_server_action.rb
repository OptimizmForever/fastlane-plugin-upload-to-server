require 'fastlane/action'
require 'mime/types'
require_relative '../helper/upload_to_server_helper'

module Fastlane
  module Actions
    module SharedValues
      UPLOAD_RESPONSE = :UPLOAD_RESPONSE
    end

    class UploadToServerAction < Action
      def self.run(config)
        params = {}
        # extract parms from config received from fastlane
        params[:endPoint] = config[:endPoint]
        params[:apk] = config[:apk]
        params[:ipa] = config[:ipa]
        params[:file] = config[:file]
        params[:method] = config[:method]
        params[:timeout] = config[:timeout] || 60

        params[:multipartPayload] = config[:multipartPayload]
        params[:headers] = config[:headers]

        apk_file = params[:apk]
        ipa_file = params[:ipa]
        custom_file = params[:file]
        
        end_point = params[:endPoint]

        UI.user_error!("No endPoint given, pass using endPoint: 'endpoint'") if end_point.to_s.length == 0 && end_point.to_s.length == 0
        UI.user_error!("No IPA or APK or a file path given, pass using `ipa: 'ipa path'` or `apk: 'apk path' or file:`") if ipa_file.to_s.length == 0 && apk_file.to_s.length == 0 && custom_file.to_s.length == 0
        UI.user_error!("Please only give IPA path or APK path (not both)") if ipa_file.to_s.length > 0 && apk_file.to_s.length > 0

        upload_custom_file(params, apk_file) if apk_file.to_s.length > 0
        upload_custom_file(params, ipa_file) if ipa_file.to_s.length > 0
        upload_custom_file(params, custom_file) if custom_file.to_s.length > 0
      end
      
      def self.upload_custom_file(params, custom_file)
        multipart_payload = params[:multipartPayload]
        file_part = Faraday::Multipart::FilePart.new(File.new(custom_file, 'rb'), MIME::Types.type_for(custom_file).first.content_type)
        key = multipart_payload[:fileFormFieldName] ? multipart_payload[:fileFormFieldName].to_s : :file
        multipart_payload[key] = file_part

        UI.message multipart_payload
        upload_file(params, multipart_payload)
      end

      def self.upload_file(params, multipart_payload)
        Actions.lane_context[SharedValues::UPLOAD_RESPONSE] = nil
        connection = Faraday.new do |conn|
          conn.request :multipart
          conn.options.timeout = params[:timeout]
        end
        response = connection.run_request(params[:method], params[:endPoint], multipart_payload, params[:headers])
        
        UI.message(response)
        if response.status == 200 || response.status == 201
          UI.success("Successfully finished uploading the fille")
        end
        Actions.lane_context[SharedValues::UPLOAD_RESPONSE] = response.body
      end

      def self.description
        "Upload IPA and APK to your own server"
      end

      def self.authors
        ["Maxim Toyberman"]
      end

      def self.return_value
        Actions.lane_context[SharedValues::UPLOAD_RESPONSE]
      end

      def self.details
        # Optional:
        "Upload IPA and APK to your custom server, with multipart/form-data"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :apk,
                                  env_name: "",
                                  description: ".apk file for the build",
                                  optional: true,
                                  default_value: Actions.lane_context[SharedValues::GRADLE_APK_OUTPUT_PATH]),
          FastlaneCore::ConfigItem.new(key: :ipa,
                                  env_name: "",
                                  description: ".ipa file for the build ",
                                  optional: true,
                                  default_value: Actions.lane_context[SharedValues::IPA_OUTPUT_PATH]),
          FastlaneCore::ConfigItem.new(key: :file,
                                  env_name: "",
                                  description: "file to be uploaded to the server",
                                  optional: true),
          FastlaneCore::ConfigItem.new(key: :multipartPayload,
                                  env_name: "",
                                  description: "payload for the multipart request ",
                                  optional: true,
                                  type: Hash),
          FastlaneCore::ConfigItem.new(key: :headers,
                                    env_name: "",
                                    description: "headers of the request ",
                                    optional: true,
                                    type: Hash),
          FastlaneCore::ConfigItem.new(key: :endPoint,
                                  env_name: "",
                                  description: "file upload request url",
                                  optional: false,
                                  default_value: "",
                                  type: String),
          FastlaneCore::ConfigItem.new(key: :method,
                                  env_name: "",
                                  description: "request method",
                                  optional: true,
                                  default_value: :post,
                                  type: Symbol),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                       env_name: "",
                                       description: "timeout",
                                       optional: true,
                                       type: Integer,
                                       default_value: 60)

        ]
      end

      def self.is_supported?(platform)
        platform == :ios || platform == :android
      end
    end
  end
end
