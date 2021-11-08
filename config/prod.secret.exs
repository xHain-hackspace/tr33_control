# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

secret_key_base = "E2JHw5yMe+7Swhe8wskPCq6J/WlCjt777d6dz85VZqe5ybBbL78+oTr3kWs9K3OJ"

config :tr33_control, Tr33ControlWeb.Endpoint, secret_key_base: secret_key_base
