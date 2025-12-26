defmodule DemoUtil do
  # Copyright (c) Microsoft Corporation.
  # Licensed under the MIT License.
  alias Microsoft.Azure.TemplateLanguageExpressions.{JSONParser, Context, Evaluator, DeploymentContext}
  alias Microsoft.Azure.ActiveDirectory.{DeviceAuthenticator, DeviceAuthenticatorSupervisor}
  alias Microsoft.Azure.ActiveDirectory.DeviceAuthenticator.Model.{State, DeviceCodeResponse}

  def login() do
    resource = "https://management.azure.com/"

    {:ok, mgmt_pid} =
      %State{
        resource: resource,
        tenant_id: "chgeuerfte.onmicrosoft.com",
        azure_environment: :azure_global
      }
      |> DeviceAuthenticatorSupervisor.start_link()

    aad_token_provider = fn _resource ->
      mgmt_pid
      |> DeviceAuthenticator.get_token()
      |> elem(1)
      |> Map.get(:access_token)
    end

    {:ok,
     %DeviceCodeResponse{
       message: message,
       user_code: user_code,
       verification_url: verification_url
     }} = mgmt_pid |> DeviceAuthenticator.get_device_code()

    %{
      mgmt_pid: mgmt_pid,
      signin: %{message: message, user_code: user_code, verification_url: verification_url},
      aad_token_provider: aad_token_provider
    }
  end

  def evaluate(json_string, deploymentContext = %DeploymentContext{}, parameters \\ %{})
      when is_binary(json_string) and is_map(parameters),
      do:
        Context.new()
        |> Context.with_json_string(json_string)
        |> Context.with_user_parameters(parameters)
        |> Context.with_deployment_context(deploymentContext)
        |> Evaluator.evaluate_arm_document()
        |> Map.fetch!(:json)
        |> JSONParser.encode()

  def transform(inputfile, deploymentContext = %DeploymentContext{}, parameters \\ %{}) do
    result =
      inputfile
      |> File.read!()
      |> evaluate(deploymentContext, parameters)

    "#{inputfile}.result.json"
    |> File.write!(result)
  end

  # def http() do
  #   {:ok, conn} = Mint.HTTP.connect(_scheme = :https, _host = "api.github.com", _port = 443)

  #   {:ok, conn, request_ref} =
  #     Mint.HTTP.request(conn, _method = "GET", _path = "/zen", _headers = [])

  #   receive do
  #     message ->
  #       {:ok, conn, responses} = Mint.HTTP.stream(conn, message)

  #       for response <- responses do
  #         case response do
  #           {:status, ^request_ref, status_code} ->
  #             IO.puts("> Response status code #{status_code}")

  #           {:headers, ^request_ref, headers} ->
  #             IO.puts("> Response headers: #{inspect(headers)}")

  #           {:data, ^request_ref, data} ->
  #             IO.puts("> Response body #{inspect(data)}")

  #           {:done, ^request_ref} ->
  #             IO.puts("> Response fully received")
  #         end
  #       end

  #       Mint.HTTP.close(conn)
  #   end
  # end

  # def az_rest(storageAccountName) do
  #   "az rest --output json --method post --uri https://management.azure.com/subscriptions/724467b5-bee4-484b-bf13-d6a5505d2b51/resourceGroups/longterm/providers/Microsoft.Storage/storageAccounts/#{
  #     storageAccountName
  #   }/listKeys?api-version=2019-04-01"
  #   |> Porcelain.shell()
  #   |> Map.fetch!(:out)
  #   |> Jason.decode!()
  #   |> Map.fetch!("keys")
  #   |> Enum.map(&(&1 |> Map.fetch!("value")))
  # end

  # def access_token() do
  #   %{
  #     "accessToken" => accessToken,
  #     "expiresOn" => expiresOn,
  #     "subscription" => subscriptionId,
  #     "tenant" => tenantId
  #   } =
  #     "az account get-access-token"
  #     # |> Kernel.to_charlist() |> :os.cmd() |> Kernel.to_string()
  #     |> Porcelain.shell()
  #     |> Map.fetch!(:out)
  #     |> Jason.decode!()

  #   %{
  #     accessToken: accessToken,
  #     expiresOn: expiresOn,
  #     subscriptionId: subscriptionId,
  #     tenantId: tenantId
  #   }
  # end

  @samples [
    ~S/{  "variables": { "a": 1 } }/,
    ~S/     {     "variables": { "a": "[createArray(1, add(1, 3), 3)]", "b": "[variables('a')[2]]"} }          /,
    ~s/\r\n{\r\n   "variables": { "a": 1 }, \r\n   "outputs": { \r\n      "foo": { "type": "int", "value": "[variables('a')]"} \r\n   } \r\n}/,
    ~s/\r\n{\r\n   "variables": { "a": 1 }, \r\n   "outputs": { \r\n      "foo": { "type": "int", "value": "[concat('foo---', string(add(3, variables('a'))), '---', guid(createArray(1, 2, 3)))]"} \r\n   } \r\n}/
  ]

  def samples(), do: @samples

  def run(deployment_context = %DeploymentContext{}),
    do:
      samples()
      |> Enum.each(fn json ->
        IO.puts("####################")
        IO.puts("Input  >>>#{json}<<<")
        IO.puts("--------------------")
        IO.puts("Output >>>#{json |> evaluate(deployment_context)}<<<")
      end)

  # def monitor(inputfile, outputfile) do
  #   # https://github.com/thekid/inotify-win/blob/master/src/Runner.cs
  #   # https://github.com/falood/file_system/blob/master/lib/file_system/backends/fs_windows.ex
  #   {:ok, pid} =
  #     __MODULE__.Watcher.start_link(backend: :fs_windows, dirs: ["c:/github/chgeuer/Desktop/f"])
  # end

  # defmodule Watcher do
  #   use GenServer

  #   def start_link(args) do
  #     GenServer.start_link(__MODULE__, args)
  #   end

  #   def init(args) do
  #     {:ok, watcher_pid} = FileSystem.start_link(args)

  #     watcher_pid |> FileSystem.subscribe()

  #     {:ok, %{watcher_pid: watcher_pid}}
  #   end

  #   def handle_info(
  #         {:file_event, watcher_pid, {path, events}},
  #         %{watcher_pid: watcher_pid} = state
  #       ) do
  #     {path, events} |> IO.inspect()

  #     {:noreply, state}
  #   end

  #   def handle_info({:file_event, watcher_pid, :stop}, %{watcher_pid: watcher_pid} = state) do
  #     {:noreply, state}
  #   end
  # end
end
