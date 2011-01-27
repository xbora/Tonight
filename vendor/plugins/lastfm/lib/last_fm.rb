require 'rexml/document'
require 'net/http'
require "digest"
require "uri"

module LastFm
  env = ENV['RAILS_ENV'] || RAILS_ENV
  config = YAML.load_file(RAILS_ROOT + '/config/last_fm.yml')[env]
  Key = config['api_key']
  Secret = config['secret']
  Prefix = "/2.0/?api_key=#{Key}&method="

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods

    def last_fm
      include LastFm::InstanceMethods
    end    
    
  end

  module InstanceMethods

    def get_signature(method,params)
      signature = []
      signature << 'method' + method
      params.each_pair do |key,value|
          signature << key.to_s + value
      end 
      signature = signature.sort.join + Secret
      return Digest::MD5.hexdigest(signature)
    end

    def fetch_last_fm(path)
          http = Net::HTTP.new("ws.audioscrobbler.com",80)
          path = url(path)
          resp, data = http.get(path)
           if resp.code == "200"
             return data
           else
             return false
           end	
    end

    def url(string)
      return  string.gsub(/\ +/, '%20')
    end

    def authenticate_lastfm
      "http://www.last.fm/api/auth/?api_key=#{Key}" 
    end

    def get_lastfm_session(token)
      signature = get_signature('auth.getsession',{:api_key=>Key,:token=>token}) 
      if
        @session = get_lastfm_with_auth('auth.getsession',{ :api_key => Key, :token => token, :signature => signature })
           session[:lastfm_name] = @session['session']['name']
           session[:lastfm_key] = @session['session']['key']
      else 
        return false
      end 
    end

    def get_lastfm(method,params,type='hash')
      http = Net::HTTP.new("ws.audioscrobbler.com",80)
      path = Prefix + method
      params.each_pair do |key,value|
        path << "&#{key}=#{value}"
      end
      resp, data = http.get(url(path))
      if resp.code == "200"
        if type == 'hash'
          hash = Hash.from_xml(data)['lfm']
          hash.shift
          return hash
        else
          return data
        end
      else 
        return resp.body
      end 
    end

    def get_lastfm_with_auth(method,params,type = 'hash')
      http = Net::HTTP.new("ws.audioscrobbler.com",80)
      path = Prefix + method
      params.each_pair do |key,value|
        path << "&#{key}=#{value}"
      end
      path << '&api_sig=' + get_signature(method,params)
      resp, data = http.get(url(path))
      if resp.code == "200"
        if type == 'hash'
          hash = Hash.from_xml(data)['lfm']
          hash.shift
          return hash
        else 
          return data
        end 
      else 
        return false
      end
    end

    def post_lastfm(method,posted)
      posted[:api_key] = Key
      posted[:sk] = session[:lastfm_key]
      signature =  get_signature(method,posted)
      posted[:api_sig] = get_signature(method,posted)
      posted[:method] = method
      resp = Net::HTTP.post_form(URI.parse('http://ws.audioscrobbler.com/2.0/'),posted)
      case resp
        when Net::HTTPSuccess, Net::HTTPRedirection
          return true
        else
          return false
      end
    end

    def lastfm_album_info(artist,album)
      path = "/1.0/album/#{artist}/#{album}/info.xml"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)	
        album = {}
        album['releasedate'] = xml.elements['releasedate'] ? xml.elements['releasedate'].text : ''
        album['url'] = xml.elements['url'] ? xml.elements['url'].text : ''
        coverart = xml.elements['//coverart']
        album['cover'] = coverart.elements['//large'] ? coverart.elements['//large'].text : ''
      
        tracks = []
        xml.elements.each('//track') do |el|
          tracks << { 
                  "title" => el.attributes["title"],
                  "url" =>   el.elements['url'] ? el.elements['url'].text : ''
                  }
        end
        album['tracks'] = tracks
      end
      return album
    end 

    def lastfm_artists_get_info(artist)
      path = "#{Prefix}artist.getinfo&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        artist = {}
          artist['mbid'] = xml.elements['mbid'] ?  xml.elements['mbid'].text : ''
          artist['url'] = xml.elements['//url'] ? xml.elements['//url'].text : ''
        if not xml.elements['//bio'].nil?
          bio = xml.elements['//bio']
            artist['bio_summary'] = bio.elements['summary'] ? bio.elements['summary'].text : ''
            artist['bio_content'] = bio.elements['content'] ? bio.elements['content'].text : ''
        end
        artist['small_image'] =  xml.elements['//artist'].elements[4].text 
        artist['medium_image'] =  xml.elements['//artist'].elements[5].text 
        artist['large_image'] =  xml.elements['//artist'].elements[6].text 
        
        if not xml.elements['//stats'].nil?
          stats = xml.elements['//stats']
            artist['stats_listeners'] = stats.elements['listeners'] ? stats.elements['listeners'].text : ''
            #artist['stats_plays'] = stats.elements['plays'] ? stats.elements['plays'].text : ''
            artist['stats_plays'] =  xml.elements['//stats'].elements[2].text 
        end
        
        
      end
      return artist
    end

    def lastfm_artists_current_events(artist, limit = 50)
      path = "#{Prefix}artist.getevents&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        events = []
         i = 1
         xml.elements.each('//event') do |event| 
           if i <= limit
             events << event_attributes_for(event)
           end
           i += 1
         end
       end
      return events 
    end
    
    def lastfm_artists_past_events(artist, limit = 50)
      path = "#{Prefix}artist.getpastevents&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        events = []
         i = 1
         xml.elements.each('//event') do |event| 
           if i <= limit
             events << event_attributes_for(event)
           end
           i += 1
         end
       end
      return events 
    end
    
    def lastfm_event_attendees(event_id)
      path = "#{Prefix}event.getattendees&event=#{event_id}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        users = []
         i = 1
         xml.elements.each('//user') do |user| 
           
             users << user_attributes_for(user)
           
           i += 1
         end
       end
      return users 
    end
    
    def lastfm_event_info(event_id)
      path = "#{Prefix}event.getinfo&event=#{event_id}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        event = xml.elements['//event']
       end
      return event_attributes_for(event) 
    end
    

    def event_bands_for event
      bands = []
      artists = event.elements['artists']
      artists.elements.each('artist') do |band|
        bands << band.text   
      end
      return bands
    end

    def user_attributes_for user
      return { 
              "name" => user.elements['name'].text, 
              "realname" => user.elements['realname'].text, 
              }
    end
    
    def event_attributes_for event
      bands = event_bands_for event
      venue = event.elements['venue']
      location = venue.elements['location']
      geo = location.elements['geo:point']
      event_image = ""
      event.elements.each('image') do |image| 
        if (image.attributes["size"] == "medium")
          event_image = image.text
        end
      end
    
      return { 
              "event_id" => event.elements['id'].text, 
              "title" => event.elements['title'].text, 
              "url" => event.elements['url'].text,  
              "date" => event.elements['startDate'].text, 
              "venue" => venue.elements['name'].text, 
              "city" => location.elements['city'].text, 
              "street" => location.elements['street'].text, 
              "zip" => location.elements['postalcode'].text,
              "geolat" => geo.elements['geo:lat'].text,
              "geolng" => geo.elements['geo:long'].text,
              "country" => location.elements['country'].text, 
              "venue_url" => venue.elements['url'].text,
              "image" => event_image,
              "bands" => bands 
              }
    end
    
    

    def lastfm_similar_artists(artist,limit = 7)
      path = "#{Prefix}artist.similar&artist=#{artist}&limit=#{limit}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        artists = []
        i = 1
        xml.elements.each('//artist') do |artist|
          if i <= limit
            artists << similiar_artists_attributes_for(artist)
          end
          i = i + 1
        end
        return artists
      end
    end
 
    def lastfm_artists_top_albums(artist,limit = 5)          
      path = "#{Prefix}artist.topAlbums&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        albums = []
        i = 1
        xml.elements.each('//album') do |album| 
          if i <= limit
            albums <<  { 
                  "name"=>album.elements['name'].text, 
                  "url" => album.elements['url'].text, 
                  "small_image" => album.elements['image'].text 
                  }
          end
          i = i + 1
        end
      end
      return albums
    end
    
    def lastfm_get_geo_events(geo, page, distance, limit = 50)          
      path = "#{Prefix}geo.getevents&location=#{geo}&page=#{page}&distance=#{distance}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        events = []
         i = 1
         xml.elements.each('//event') do |event| 
           if i <= limit
             events << event_attributes_for(event)
           end
           i += 1
         end
       end
      return events
    end

    def lastfm_artists_top_tracks(artist, limit = 5)          
      path = "#{Prefix}artist.topTracks&artist=#{artist}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        tracks = []
        i = 1
        xml.elements.each('//track') do |track| 
          if i <= limit
            tracks << {
                  "name"=>track.elements['name'].text,
                  "url"=>track.elements['url'].text
                  }
          end 
          i = i + 1
        end
      end
      return tracks
    end

    def lastfm_tracks_top_tags(artist, track, limit = 5)
      path = "#{Prefix}track.getTopTags&artist=#{artist}&track=#{track}"
      data = fetch_last_fm(path)
      process_tags_for data, limit
    end

    def lastfm_artists_top_tags(artist, limit = 10)
      path = "#{Prefix}artist.getTopTags&artist=#{artist}"
      data = fetch_last_fm(path)
      process_tags_for data, limit
    end
        
    def lastfm_users_weekly_artists(user, limit = 30)
      path = "#{Prefix}user.getWeeklyArtistChart&user=#{user}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        bands = []
        i = 1
        xml.elements.each('//artist') do |band| 
          if i <= limit
            bands << users_weekly_artists_attributes_for(band)
          end
          i = + i + 1
        end
        return bands
      end
    end

    def lastfm_users_weekly_albums(user, limit = 10)
      path = "#{Prefix}user.getWeeklyAlbumChart&user=#{user}"
      data = fetch_last_fm(path)
      if not data == false
        xml = REXML::Document.new(data)
        albums = []
        i = 1
        xml.elements.each('//album') do |album| 
          if i <= limit
            albums << users_weekly_albums_attributes_for(album)
          end
          i = i + 1
        end
        return albums
      end
    end
  
  private

  def process_tags_for data, limit
        if not data == false
          xml = REXML::Document.new(data)
          tags = []
          i = 1
          xml.elements.each('//tag') do |tag|
            if i <= limit
              tags << { 'tag' => tag.elements['name'].text, 'url' => tag.elements['url'].text }              
            end
            i = i + 1
          end
          return tags
        end
  end

    def users_weekly_artists_attributes_for band
       { "name" => band.elements['name'].text, 
        "url" => band.elements['url'].text,
        "mbid" => band.elements['mbid'].text,
        "playcount" => band.elements['playcount'].text,
        "rank" => band.attributes['rank'] 
        }
    end

    def users_weekly_albums_attributes_for album
       { 
          "name" => album.elements['name'].text,
          "band" => album.elements['artist'].text,
          "url" => album.elements['url'].text,
          "album_mbid" => album.elements['mbid'].text,
          "playcount" => album.elements['playcount'].text,
          "artist_mbid" => album.elements['artist'].attributes['mbid'],
          "rank" => album.attributes['rank']
      }
    end

    def similiar_artists_attributes_for artist
         {
            "name" => artist.elements['name'] ? artist.elements['name'].text : '',
            "url" => artist.elements['url'] ? artist.elements['url'].text :  '' ,
            "image" => artist.elements['image'] ? artist.elements['image'].text : '',
            "small_image" => artist.elements['image'] ? artist.elements['image'].text : '',
            "mbid" => artist.elements['mbid'] ? artist.elements['mbid'].text : '',
            "match" => artist.elements['match'] ? artist.elements['match'].text : ''
            }
    end
 
  end
 
end 