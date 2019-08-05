defmodule Explorer.Staking.ContractStateTest do
  use EthereumJSONRPC.Case
  use Explorer.DataCase

  import Mox

  alias Explorer.Chain.{StakingPool, StakingPoolsDelegator}
  alias Explorer.Chain.Events.Publisher
  alias Explorer.Repo
  alias Explorer.Staking.ContractState

  setup :verify_on_exit!
  setup :set_mox_global

  test "when disabled, returns default values" do
    assert ContractState.get(:epoch_number, 0) == 0
    assert ContractState.get(:epoch_end_block, 0) == 0
    assert ContractState.get(:min_delegator_stake, 1) == 1
    assert ContractState.get(:min_candidate_stake, 1) == 1
    assert ContractState.get(:token_contract_address) == nil
  end

  test "fetch new epoch data" do
    set_init_mox()
    set_mox()

    Application.put_env(:explorer, ContractState,
      enabled: true,
      staking_contract_address: "0x1100000000000000000000000000000000000001"
    )

    start_supervised!(ContractState)

    set_mox()
    Publisher.broadcast([{:blocks, [%Explorer.Chain.Block{number: 6000}]}], :realtime)
    Publisher.broadcast([{:blocks, [%Explorer.Chain.Block{number: 5999}]}], :realtime)
    Publisher.broadcast([{:blocks, [%Explorer.Chain.Block{number: 6000}]}], :realtime)

    set_mox()
    Publisher.broadcast([{:blocks, [%Explorer.Chain.Block{number: 6001}]}], :realtime)

    Process.sleep(500)

    assert ContractState.get(:epoch_number) == 74
    assert ContractState.get(:epoch_end_block) == 6000
    assert ContractState.get(:min_delegator_stake) == 1_000_000_000_000_000_000
    assert ContractState.get(:min_candidate_stake) == 1_000_000_000_000_000_000
    assert ContractState.get(:token_contract_address) == "0x6f7a73c96bd56f8b0debc795511eda135e105ea3"

    assert Repo.aggregate(StakingPool, :count, :id) == 4
    assert Repo.aggregate(StakingPoolsDelegator, :count, :id) == 3
  end

  defp set_init_mox() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn requests, _opts ->
        assert length(requests) == 1
        {:ok, format_responses(["0x0000000000000000000000001000000000000000000000000000000000000001"])}
      end
    )

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn requests, _opts ->
        assert length(requests) == 1
        {:ok, format_responses(["0x0000000000000000000000002000000000000000000000000000000000000001"])}
      end
    )
  end

  defp set_mox() do
    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn requests, _opts ->
        assert length(requests) == 10

        {:ok,
         format_responses([
           "0x0000000000000000000000006f7a73c96bd56f8b0debc795511eda135e105ea3",
           "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
           "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
           "0x000000000000000000000000000000000000000000000000000000000000004a",
           "0x0000000000000000000000000000000000000000000000000000000000001770",
           "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000030000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6000000000000000000000000b916e7e1f4bcb13549602ed042d36746fd0d96c9000000000000000000000000db9cb2478d917719c53862008672166808258577",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000b6695f5c2e3f5eff8036b5f5f3a9d83a5310e51e",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000002000000000000000000000000b916e7e1f4bcb13549602ed042d36746fd0d96c9000000000000000000000000db9cb2478d917719c53862008672166808258577",
           "0x00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000514000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000c8000000000000000000000000000000000000000000000000000000000000044c",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000003000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c78000000000000000000000000f67cc5231c5858ad6cc87b105217426e17b824bb000000000000000000000000be69eb0968226a1808975e1a1f2127667f2bffb3"
         ])}
      end
    )

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn requests, _opts ->
        assert length(requests) == 36

        {:ok,
         format_responses([
           "0x000000000000000000000000bbcaa8d48289bb1ffcf9808d9aa4b1d215054c78",
           "0x0000000000000000000000000000000000000000000000000000000000000001",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x000000000000000000000000000000000000000000000000000000000003d090",
           "0x000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000b2f5e2f3cbd864eaa2c642e3769c1582361caf6",
           "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000f4240",
           "0x000000000000000000000000f67cc5231c5858ad6cc87b105217426e17b824bb",
           "0x0000000000000000000000000000000000000000000000000000000000000001",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000001bc16d674ec80000",
           "0x0000000000000000000000000000000000000000000000001bc16d674ec80000",
           "0x0000000000000000000000000000000000000000000000000000000000051615",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000b916e7e1f4bcb13549602ed042d36746fd0d96c9",
           "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000f4240",
           "0x000000000000000000000000be69eb0968226a1808975e1a1f2127667f2bffb3",
           "0x0000000000000000000000000000000000000000000000000000000000000001",
           "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000200000000000000000000000009d99f80d3b59cca783f11918311fb31212fb7500000000000000000000000008d6867958e1cab5c39160a1d30fbc68ac55b45ef",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000",
           "0x00000000000000000000000000000000000000000000000098a7d9b8314c0000",
           "0x0000000000000000000000000000000000000000000000001bc16d674ec80000",
           "0x0000000000000000000000000000000000000000000000000000000000051615",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000db9cb2478d917719c53862008672166808258577",
           "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000f4240",
           "0x000000000000000000000000720e118ab1006cc97ed2ef6b4b49ac04bb3aa6d9",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000e4978fac7adfc925352dbc7e1962e6545142eeee",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000",
           "0x00000000000000000000000000000000000000000000000029a2241af62c0000",
           "0x0000000000000000000000000000000000000000000000001bc16d674ec80000",
           "0x0000000000000000000000000000000000000000000000000000000000051615",
           "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000b6695f5c2e3f5eff8036b5f5f3a9d83a5310e51e",
           "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000f4240"
         ])}
      end
    )

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn requests, _opts ->
        assert length(requests) == 20

        {:ok,
         format_responses([
           "0x0000000000000000000000000000000000000000000000000000000000000001",
           "0x000000000000000000000000000000000000000000000000000000000000004b",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000002",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000001",
           "0x000000000000000000000000000000000000000000000000000000000000004a",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000001",
           "0x000000000000000000000000000000000000000000000000000000000000004a",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000"
         ])}
      end
    )

    expect(
      EthereumJSONRPC.Mox,
      :json_rpc,
      fn requests, _opts ->
        assert length(requests) == 15

        {:ok,
         format_responses([
           "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000de0b6b3a7640000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000",
           "0x0000000000000000000000000000000000000000000000000000000000000000"
         ])}
      end
    )
  end

  defp format_responses(responses) do
    responses
    |> Enum.with_index()
    |> Enum.map(fn {response, index} ->
      %{
        id: index,
        jsonrpc: "2.0",
        result: response
      }
    end)
  end
end
