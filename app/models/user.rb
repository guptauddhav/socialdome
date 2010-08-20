require 'digest/sha1'

class User < ActiveRecord::Base
  
  validates_length_of :username, :within => 5..40
  
  validates_length_of :password, :within => 5..40
  
  validates_presence_of :username, :email, :password, :password_confirmation, 
                        :firstname, :lastname
  
  validates_uniqueness_of :username, :email
  
  validates_confirmation_of :password
  
  validates_format_of :email, 
                      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, 
                      :message => "Invalid email"  
  
  attr_protected :id, :salt
  
  attr_accessor :password, :password_confirmation
  
  before_create :prepare_activation
  
  after_create :send_activate
  
  # authenticates the user.
  # @param username username of the user.
  # @param password password of the user.
  #       
  def self.authenticate(username, pass)
    u = find(:first, :conditions=>["username = ?", username])
    return nil if u.nil?
    return u if User.encrypt(pass, u.salt) == u.hashed_password
  end
  
  def password=(pass)
    @password = pass
    self.salt = User.random_string(10) if !self.salt?
    self.hashed_password = User.encrypt(@password, self.salt)
  end
  
  # sends out a password reset mail.
  #
  def send_password_reset_mail
    Notifications.deliver_password_reset(self)
  end
  
  # sends out a activation email.
  #
  def send_activate
    Notifications.deliver_activate(self)
  end
  
  # activates a user after the user clicks the activation url.
  #
  def activate!
    self.active = true
    self.created_at = Time.now.utc
    self.activation_id = nil
    save(false)
  end
  
  # creates a password reset token.
  #
  def make_reset_token
    self.reset_token = self.class.make_token
  end
  
  # clears the password reset token.
  #
  def clear_reset_token
    self.reset_token = nil
  end
  
  #
  # Deletes the server-side record of the authentication token. The
  # client-side (browser cookie) and server-side (this remember_token) must
  # always be deleted together.
  #
  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token = nil
    save(false)
  end
  
  
  def remember_token?
    (!remember_token.blank?) &&
      remember_token_expires_at && (Time.now.utc < remember_token_expires_at.utc)
  end
  
  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token = self.class.make_token
    save(false)
  end

  # refresh token (keeping same expires_at) if it exists
  def refresh_token
    if remember_token?
      self.remember_token = self.class.make_token
      save(false)
    end
  end
  
  protected
  
  def prepare_activation
    self.activation_id = self.class.make_token
    self.created_at ||= Time.now
  end
  
  private 
  
  def self.random_string(len)
    #generat a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end
  
  def self.encrypt(pass, salt)
    Digest::SHA1.hexdigest(pass+salt)
  end
  
  def self.secure_digest(*args)
    Digest::SHA1.hexdigest(args.flatten.join('--'))
  end
  
  def self.make_token
    secure_digest(Time.now, (1..10).map{ rand.to_s })
  end
  
end
