defmodule Angle.Media.StorageTest do
  use ExUnit.Case, async: true

  alias Angle.Media.Storage

  describe "url/1" do
    test "constructs full URL from remote key" do
      url = Storage.url("items/abc/thumb.webp")
      assert url =~ "items/abc/thumb.webp"
      assert url =~ "http"
    end
  end

  describe "mock storage" do
    test "upload succeeds" do
      assert :ok =
               Angle.Media.Storage.Mock.upload(
                 "/tmp/test.webp",
                 "items/abc/test.webp",
                 "image/webp"
               )
    end

    test "delete succeeds" do
      assert :ok = Angle.Media.Storage.Mock.delete("items/abc/test.webp")
    end
  end

  describe "dispatch to configured module" do
    test "upload dispatches to mock in test env" do
      # In test env, storage_module is set to Mock
      assert :ok = Storage.upload("/tmp/test.webp", "test/key.webp", "image/webp")
    end

    test "delete dispatches to mock in test env" do
      assert :ok = Storage.delete("test/key.webp")
    end
  end
end
