defmodule AngleWeb.UploadControllerTest do
  use AngleWeb.ConnCase, async: true

  @fixture_path "test/support/fixtures"

  defp authed_conn(conn, user) do
    conn |> init_test_session(%{current_user_id: user.id})
  end

  setup do
    user = create_user()
    item = create_item(%{created_by_id: user.id, title: "Test Item"})

    # Ensure test image exists
    File.mkdir_p!(@fixture_path)
    image_path = Path.join(@fixture_path, "test_image.jpg")

    unless File.exists?(image_path) do
      {:ok, image} = Image.new(200, 200, color: :red)
      Image.write(image, image_path)
    end

    upload = %Plug.Upload{
      path: image_path,
      content_type: "image/jpeg",
      filename: "test_image.jpg"
    }

    %{user: user, item: item, upload: upload}
  end

  describe "POST /uploads" do
    test "uploads an image for an item", %{conn: conn, user: user, item: item, upload: upload} do
      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      assert %{"id" => id, "variants" => variants, "position" => 0} =
               json_response(conn, 201)

      assert is_binary(id)
      assert Map.has_key?(variants, "thumbnail")
      assert Map.has_key?(variants, "medium")
      assert Map.has_key?(variants, "full")
    end

    test "uploads an avatar for a user", %{conn: conn, user: user, upload: upload} do
      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/uploads", %{
          "file" => upload,
          "owner_type" => "user_avatar",
          "owner_id" => user.id
        })

      assert %{"id" => _, "position" => 0} = json_response(conn, 201)
    end

    test "rejects unauthenticated uploads", %{conn: conn, item: item, upload: upload} do
      conn =
        post(conn, ~p"/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      # Should redirect to login
      assert redirected_to(conn) == ~p"/auth/login"
    end

    test "rejects invalid MIME type", %{conn: conn, user: user, item: item} do
      upload = %Plug.Upload{
        path: Path.join(@fixture_path, "test_image.jpg"),
        content_type: "image/gif",
        filename: "test.gif"
      }

      conn =
        conn
        |> authed_conn(user)
        |> post(~p"/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "rejects uploads for items the user doesn't own", %{
      conn: conn,
      item: item,
      upload: upload
    } do
      other_user = create_user()

      conn =
        conn
        |> authed_conn(other_user)
        |> post(~p"/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      assert json_response(conn, 403)
    end

    test "auto-increments position for item images", %{
      conn: conn,
      user: user,
      item: item,
      upload: upload
    } do
      # Upload first image
      conn
      |> authed_conn(user)
      |> post(~p"/uploads", %{
        "file" => upload,
        "owner_type" => "item",
        "owner_id" => item.id
      })

      # Upload second image
      conn2 =
        conn
        |> recycle()
        |> authed_conn(user)
        |> post(~p"/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      assert %{"position" => 1} = json_response(conn2, 201)
    end

    test "replaces existing avatar on re-upload", %{conn: conn, user: user, upload: upload} do
      conn
      |> authed_conn(user)
      |> post(~p"/uploads", %{
        "file" => upload,
        "owner_type" => "user_avatar",
        "owner_id" => user.id
      })

      conn2 =
        conn
        |> recycle()
        |> authed_conn(user)
        |> post(~p"/uploads", %{
          "file" => upload,
          "owner_type" => "user_avatar",
          "owner_id" => user.id
        })

      assert %{"position" => 0} = json_response(conn2, 201)

      images =
        Angle.Media.Image
        |> Ash.Query.for_read(:by_owner, %{owner_type: :user_avatar, owner_id: user.id},
          authorize?: false
        )
        |> Ash.read!()

      assert length(images) == 1
    end
  end

  describe "DELETE /uploads/:id" do
    test "deletes an image", %{conn: conn, user: user, item: item, upload: upload} do
      create_conn =
        conn
        |> authed_conn(user)
        |> post(~p"/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      %{"id" => image_id} = json_response(create_conn, 201)

      delete_conn =
        conn
        |> recycle()
        |> authed_conn(user)
        |> delete(~p"/uploads/#{image_id}")

      assert delete_conn.status == 204
    end

    test "rejects deletion by non-owner", %{conn: conn, user: user, item: item, upload: upload} do
      create_conn =
        conn
        |> authed_conn(user)
        |> post(~p"/uploads", %{
          "file" => upload,
          "owner_type" => "item",
          "owner_id" => item.id
        })

      %{"id" => image_id} = json_response(create_conn, 201)

      other_user = create_user()

      delete_conn =
        conn
        |> recycle()
        |> authed_conn(other_user)
        |> delete(~p"/uploads/#{image_id}")

      assert delete_conn.status == 403
    end
  end

  describe "PATCH /uploads/reorder" do
    test "reorders item images", %{conn: conn, user: user, item: item, upload: upload} do
      ids =
        for _ <- 0..2 do
          resp =
            conn
            |> recycle()
            |> authed_conn(user)
            |> post(~p"/uploads", %{
              "file" => upload,
              "owner_type" => "item",
              "owner_id" => item.id
            })
            |> json_response(201)

          resp["id"]
        end

      reversed = Enum.reverse(ids)

      reorder_conn =
        conn
        |> recycle()
        |> authed_conn(user)
        |> patch(~p"/uploads/reorder", %{"item_id" => item.id, "image_ids" => reversed})

      assert %{"images" => images} = json_response(reorder_conn, 200)
      assert Enum.map(images, & &1["id"]) == reversed
    end
  end
end
