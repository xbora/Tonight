# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_tonight_session',
  :secret      => '2b2cccf1c7f402960da474a39046965c088f55ae10b325c047f992f131c607318f04735f0469f58d6b019fb9207ea290f015b08fb5cf8e3d76b98581f774b60d'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
