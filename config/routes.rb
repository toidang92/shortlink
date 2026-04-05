Rails.application.routes.draw do
  post 'encode', to: 'urls#encode'
  post 'decode', to: 'urls#decode'

  get 'up' => 'rails/health#show', as: :rails_health_check

  get ':code', to: 'redirect#show', constraints: { code: /[a-zA-Z0-9]{6}/ }
end
