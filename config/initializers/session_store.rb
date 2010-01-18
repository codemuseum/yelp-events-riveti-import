# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_yelp-events-riveti-import_session',
  :secret      => 'ef991ee352f085beb5048af0a23dc7bd09ce117391729446e4e92e4152dc5cf7962e208049958d3bc7bbc0d5ca4210628122471081ee890299942c7851bec309'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
