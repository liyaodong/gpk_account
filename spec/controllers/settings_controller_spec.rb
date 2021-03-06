require 'rails_helper'

RSpec.describe SettingsController, type: :controller do
  context 'regular user' do
    let(:user) { create(:basic_user) }
    let(:full_user) { create(:full_user) }

    before do
      warden.set_user user
    end

    describe 'PATCH settings#update_preference' do
      it 'build right params' do
        param_hash = {
          'preference' => {
            'email' => {
              'enabled' => false,
              'subscriptions' => {
                'event' => 'unsubscribed',
                'report' => 'unsubscribed'
              }
            }
          }
        }
        patch :update_preference, user: param_hash
        expect(user.preference.email).to eq param_hash['preference']['email']
      end
    end

    describe 'PATCH settings#update_password with new password' do
      it 'should return error if password is invalid' do
        patch :update_password, password: '111111', new_password: '222222'
        expect(JSON.parse(response.body)['errors']).to include('密码错误')
      end

      it 'should return error if new password is invalid' do
        patch :update_password, password: user.password, new_password: '12345'
        expect(JSON.parse(response.body)['errors']).to include('Password过短（最短为 6 个字符）')
      end

      it 'should update password and return user' do
        patch :update_password, password: user.password, new_password: '123456'
        expect(JSON.parse(response.body)['email']).to eq('u****@geekpark.net')
        expect(user.authenticate('123456')).to eq(user)
      end
    end

    describe 'DELETE settings#unbind_auth' do
      before do
        warden.set_user full_user
      end

      it 'should delete authorization' do
        delete :unbind_auth, provider: 'wechat'
        expect(response).to be_success
        expect(JSON.parse(response.body)['email']).to eq('u****@geekpark.net')
      end

      it 'should return error if Authorization not found' do
        delete :unbind_auth, provider: 'wechat'
        delete :unbind_auth, provider: 'wechat'
        expect(JSON.parse(response.body)['errors']).to include('第三方帐号不存在')
      end
    end

    describe 'POST settings#identified' do
      it 'should return false' do
        post :identified
        expect(JSON.parse(response.body)['identified']).to eq(false)
      end

      it 'should return false' do
        token = user.generate_identify_token
        cookies[:identify_token] = token
        post :identified
        expect(JSON.parse(response.body)['identified']).to eq(true)
      end
    end
  end

  context 'old user or sns user' do
    let(:old_user) { create(:old_user) }

    describe 'POST settings#identified' do
      it 'should return true' do
        warden.set_user old_user
        post :identified
        expect(JSON.parse(response.body)['identified']).to eq(true)
      end
    end
  end
end
