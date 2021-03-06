require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  let(:user) { create(:full_user) }
  let(:basic_user) { create(:basic_user) }

  describe 'current_user' do
    it 'returns user from cookie' do
      request.cookies[:remember_token] = user.generate_remember_token
      request.cookies[:remember_user] = user.id
      get :new
      expect(warden.user).to eq(user)
      expect(response).to redirect_to(user_url)
    end
  end

  describe 'GET #new' do
    it 'returns http success' do
      get :new
      expect(response).to have_http_status(:success)
    end

    it 'redirect to root_url user already login' do
      warden.set_user(user)
      get :new
      expect(response).to redirect_to(user_url)
    end
  end

  describe 'POST #create' do
    context 'user login with password' do
      it 'failed with wrong password' do
        post :create, login_name: user.email, password: '123456'
        expect(warden.user).to be_nil
      end

      it 'contain error message when login failed' do
        post :create, login_name: user.email, password: '123456'
        expect(session[:unauthorized_user]).not_to be_nil
      end

      it 'failed no warden strategies fetched' do
        post :create
        expect(warden.user).to be_nil
      end

      it 'success with correct password' do
        post :create, login_name: user.email, password: 'password'
        expect(warden.user).to eq(user)
        expect(response).to redirect_to(user_url)
      end

      it 'will set remember_token if remember_me' do
        post :create, login_name: user.email, password: 'password', remember_me: true
        expect(request.cookies['remember_token']).to eq(user.remember_token)
      end

      it 'redirect_to two_factor_verify url when enabled' do
        user.update_attribute(:two_factor_enable, true)
        post :create, login_name: user.email, password: 'password'
        expect(response).to redirect_to(two_factor_verify_url)
      end

      it 'login with two_factor code' do
        session[:user_need_verify] = { 'id' => user.id }
        post :create, otp_code: user.otp_code
        expect(warden.user).to eq(user)
      end

      it 'not login without session' do
        post :create, otp_code: user.otp_code
        expect(warden.user).to be_nil
      end
    end

    context 'user login with omniauth' do
      before { request.env['omniauth.auth'] = mock_wechat_auth }

      it 'should successfully create a user when user first login' do
        expect { post :create, provider: :wechat }.to change { User.count }.by(1)
      end

      it 'should login without create user when user exsit' do
        user = User.create_with_omniauth(mock_wechat_auth)
        expect { post :create, provider: :wechat }.to change { User.count }.by(0)

        expect(warden.user).to eq(user)
      end

      it 'should redirect to valid location' do
        url = 'https://example.org/callback'
        request.env['omniauth.redirect'] = url
        expect(post(:create, provider: :wechat)).to redirect_to(url)
      end

      it 'should reject malicious redirections' do
        malicious_uri = "data:text/html,<script>alert('1');</script>"
        request.env['omniauth.redirect'] = URI.encode(malicious_uri)
        expect(post(:create, provider: :wechat)).to be_a_bad_request
      end
    end

    context 'bind auth if omniauth request and user already logged in' do
      before do
        request.env['omniauth.auth'] = mock_wechat_auth
        warden.set_user basic_user
      end

      it 'should create an authorization' do
        expect { post :create }.to change { basic_user.authorizations.count }.by(1)
        expect(response).to redirect_to('/#/third')
      end

      it 'should return error if uid is exist' do
        post :create
        post :create
        expect(response).to redirect_to('/#/third')
        msg = I18n.translate('errors.authorization_bind_failed',
          provider: I18n.translate("authorizations.providers.#{mock_wechat_auth['provider']}"))
        expect(flash[:error]).to eq(msg)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'returns http success' do
      warden.set_user(user)
      expect(warden.user).to eq(user)
      delete :destroy
      expect(warden.user).to be_nil
    end

    it "empty the user's remember_token" do
      user.generate_remember_token
      warden.set_user(user)
      delete :destroy
      expect(user.remember_token).to be_nil
    end
  end
end
