Rails.application.routes.draw do
  post 'encode', to: 'short_links#encode'
  post 'decode', to: 'short_links#decode'

  get 'up' => 'rails/health#show', as: :rails_health_check

  get ':code', to: 'redirect#show', constraints: { code: AppConstants::REDIRECT_CODE_REGEX }
end
