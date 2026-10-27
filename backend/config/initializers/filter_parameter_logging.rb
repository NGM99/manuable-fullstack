Rails.application.config.filter_parameters += [
  :passw, :email, :correo, :secret, :token, :_key, :crypt, :salt,
  :certificate, :otp, :ssn, :authorization
]
