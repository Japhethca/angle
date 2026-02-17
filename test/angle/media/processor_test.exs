defmodule Angle.Media.ProcessorTest do
  use ExUnit.Case, async: true

  alias Angle.Media.Processor

  @fixture_path "test/support/fixtures"
  @test_image Path.join(@fixture_path, "test_image.jpg")

  setup_all do
    File.mkdir_p!(@fixture_path)
    path = Path.join(@fixture_path, "test_image.jpg")

    unless File.exists?(path) do
      {:ok, image} = Image.new(200, 200, color: :red)
      Image.write(image, path)
    end

    %{image_path: path}
  end

  describe "generate_variants/1" do
    test "generates thumbnail, medium, and full variants", %{image_path: path} do
      assert {:ok, result} = Processor.generate_variants(path)

      assert Map.has_key?(result, :thumbnail)
      assert Map.has_key?(result, :medium)
      assert Map.has_key?(result, :full)

      for {_name, variant_path} <- result, is_binary(variant_path) do
        assert File.exists?(variant_path), "Variant file should exist: #{variant_path}"
        assert String.ends_with?(variant_path, ".webp")
      end
    end

    test "returns original dimensions", %{image_path: path} do
      assert {:ok, result} = Processor.generate_variants(path)
      assert result.original_width == 200
      assert result.original_height == 200
    end

    test "cleans up temp files on cleanup call", %{image_path: path} do
      assert {:ok, result} = Processor.generate_variants(path)

      variant_paths = for {name, p} <- result, name in [:thumbnail, :medium, :full], do: p
      Enum.each(variant_paths, fn p -> assert File.exists?(p) end)

      Processor.cleanup(result)

      Enum.each(variant_paths, fn p -> refute File.exists?(p) end)
    end
  end

  describe "validate_file/2" do
    test "accepts jpeg" do
      assert :ok = Processor.validate_file(@test_image, "image/jpeg")
    end

    test "accepts png" do
      assert :ok = Processor.validate_file(@test_image, "image/png")
    end

    test "accepts webp" do
      assert :ok = Processor.validate_file(@test_image, "image/webp")
    end

    test "rejects unsupported types" do
      assert {:error, :invalid_type} = Processor.validate_file(@test_image, "image/gif")
    end

    test "rejects non-image files" do
      # Create a temporary text file that claims to be an image
      tmp_path = Path.join(System.tmp_dir!(), "fake_image.jpg")
      File.write!(tmp_path, "not an image")

      assert {:error, :invalid_type} = Processor.validate_file(tmp_path, "image/jpeg")

      File.rm(tmp_path)
    end
  end

  describe "validate_file_size/1" do
    test "rejects files over 10MB" do
      assert {:error, :file_too_large} = Processor.validate_file_size(11_000_000)
    end

    test "accepts files under 10MB" do
      assert :ok = Processor.validate_file_size(5_000_000)
    end
  end
end
