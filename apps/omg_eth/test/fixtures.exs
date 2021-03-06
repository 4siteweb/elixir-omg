# Copyright 2018 OmiseGO Pte Ltd
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule OMG.Eth.Fixtures do
  @moduledoc """
  Contains fixtures for tests that require geth and contract
  """
  use ExUnitFixtures.FixtureModule

  alias OMG.Eth

  deffixture geth do
    {:ok, exit_fn} = Eth.DevGeth.start()
    on_exit(exit_fn)
    :ok
  end

  deffixture contract(geth) do
    :ok = geth

    Eth.DevHelpers.prepare_env!("../../")
  end

  deffixture token(root_chain_contract_config) do
    :ok = root_chain_contract_config

    root_path = "../../"
    {:ok, [addr | _]} = Ethereumex.HttpClient.eth_accounts()
    {:ok, _, token_addr} = OMG.Eth.DevHelpers.create_new_token(root_path, addr)

    # ensuring that the root chain contract handles token_addr
    {:ok, false} = Eth.DevHelpers.has_token(token_addr)
    {:ok, _} = Eth.DevHelpers.add_token(token_addr)
    {:ok, true} = Eth.DevHelpers.has_token(token_addr)

    %{address: token_addr}
  end

  deffixture root_chain_contract_config(contract) do
    Application.put_env(:omg_eth, :contract_addr, contract.contract_addr, persistent: true)
    Application.put_env(:omg_eth, :authority_addr, contract.authority_addr, persistent: true)
    Application.put_env(:omg_eth, :txhash_contract, contract.txhash_contract, persistent: true)

    {:ok, started_apps} = Application.ensure_all_started(:omg_eth)

    on_exit(fn ->
      Application.put_env(:omg_eth, :contract_addr, "0x0")
      Application.put_env(:omg_eth, :authority_addr, "0x0")
      Application.put_env(:omg_eth, :txhash_contract, "0x0")

      started_apps
      |> Enum.reverse()
      |> Enum.map(fn app -> :ok = Application.stop(app) end)
    end)

    :ok
  end

  deffixture token_contract_config(token) do
    # ensuring that the child chain handles the token (esp. fee-wise)

    {:ok, enc_eth} = OMG.API.Crypto.encode_address(OMG.API.Crypto.zero_address())
    {:ok, path} = OMG.API.TestHelper.write_fee_file(%{enc_eth => 0, token.address => 0})
    default_path = Application.get_env(:omg_api, :fee_specs_file_path)
    Application.put_env(:omg_api, :fee_specs_file_path, path, persistent: true)

    on_exit(fn ->
      Application.put_env(:omg_api, :fee_specs_file_path, default_path)
    end)

    :ok
  end
end
