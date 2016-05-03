class UsersController < ApplicationController
  include Verifiable
  before_action :require_login, only: [:show, :update]
  before_action :verify_rucaptcha!, only: [:verify_mobile, :verify_email]

  def new
  end

  def show
    user = UserSerializer.new(current_user)
    @data = { user: user, city: get_city_list(user.city) }.to_json
    respond_to do |format|
      format.html
      format.json { render json: @data }
    end
  end

  def update
    current_user.update!(user_update_params)
    render json: current_user, serializer: UserSerializer
  end

  def create
    if verify_code?
      user = User.create!(user_create_params)
      warden.set_user(user)
      render json: { user: UserSerializer.new(current_user), callback_url: callback_url }
    else
      render json: { errors: ['Verify code invalid'] }, status: 422
    end
  end

  def reset_password
    user = User.find_by_email_or_mobile(login_name)
    (render json: { errors: ['User not found'] }, status: 404) && return unless user
    if verify_code?
      user.update!(password: params[:user][:password])
      warden.set_user(user)
      render json: { user: user, callback_url: callback_url }
    else
      render json: { errors: ['Verify code invalid'] }, status: 422
    end
  end

  def check_exist
    render json: { exist: User.find_by_email_or_mobile(login_name).present? }
  end

  private

  def user_create_params
    params.require(:user).permit(:email, :mobile, :password)
  end

  def user_update_params
    params.require(:user).permit(:nickname, :city, :company, :title, :avatar, :bio, :realname, :gender, :birthday)
  end

  def verify_rucaptcha!
    @user = User.find_by_email_or_mobile(login_name) || User.new(user_create_params)
    unless verify_rucaptcha?(@user) && @user.valid?
      render json: { errors: @user.errors.full_messages }, status: 422
      return
    end
  end

  def generate_verify_code(key)
    Rails.cache.fetch "verify_code:#{key}", expires_in: 30.minutes do
      rand(100_000..999_999).to_s
    end
  end

  def verify_code?
    code = Rails.cache.fetch "verify_code:#{login_name}"
    code.present? && code == params[:verify_code]
  end

  def get_city_list(id)
    return [ChinaCity.list, nil, nil] if id.nil?
    [
      ChinaCity.list,
      ChinaCity.list("#{id / 1000}000"),
      ChinaCity.list("#{id / 100}00")
    ]
  end
end
