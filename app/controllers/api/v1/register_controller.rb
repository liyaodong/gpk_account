class Api::V1::RegisterController < Api::BaseController
  include Verifiable
  before_action :verify_signature!, only: :register
  before_action :verify_user_exist!, only: [:send_verify_code]
  before_action :verify_rucaptcha!, only: :send_verify_code

  def captcha
    hex = SecureRandom.hex
    captcha = RuCaptcha::Captcha.random_chars
    Rails.cache.write "captcha_key:#{hex}", captcha, expired_in: 2.minutes
    response.headers['captcha_key'] = hex
    send_data RuCaptcha::Captcha.create(captcha)
  end

  def register
    verify_code?(params[:user][:mobile] || params[:user][:email])
    user = User.create! register_param
    token = Doorkeeper::AccessToken.find_or_create_for(@client, user.id, @client.scopes, 7200, true)
    render json: token
  end

  private

  def register_param
    params.require(:user).permit(:email, :mobile, :password)
  end

  def verify_rucaptcha!
    if params[:captcha_key].present?
      (captcha = Rails.cache.read "captcha_key:#{params[:captcha_key]}") &&
        Rails.cache.delete("captcha_key:#{params[:captcha_key]}")
    end

    right = params[:captcha].present? && captcha == params[:captcha]

    (render json: { error: t('errors.invalid_captcha') }, status: 422) && return unless right
  end

  def verify_user_exist!
    user = User.find_by_email(params[:email] || '') || User.find_by_mobile(params[:mobile] || '')
    (render json: { error: 'send fail', message: t('errors.account_already_exist') }, status: 422) && return if user
  end
end
