defmodule HelloWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, socket}
  end

  def join("room:" <> _private_room_id, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def terminate(_reason, socket) do
    IO.puts "~~~~~~~~~~~Terminated~~~~~~~~~~~~"
    username = :ets.match(:reverseuserinfo, {socket.id, :"$2"})
    username = Enum.at(username, 0)
    if username != nil do
        username = Enum.at(username, 0)
    end
    IO.inspect username
    socketid = :ets.match(:userinfo, {username, :"$2"}) 
    IO.inspect socketid

    :ets.delete(:userinfo, username)
    deletedsock = :ets.match(:userinfo, {username, :"$2"}) 
    IO.inspect deletedsock

    :ets.delete(:reverseuserinfo, socket.id)
    deleteduser = :ets.match(:reverseuserinfo, {socket.id, :"$2"})
    IO.inspect deleteduser
    :ok
  end

  def handle_in("login", %{"body" => body}, socket) do
    :ets.insert(:userinfo, {body, socket.id})
    :ets.insert(:reverseuserinfo, {socket.id,  body})
    li = :ets.match(:userinfo, {body, :"$2"})
    IO.inspect li
    offlineTweets = :ets.match(:offlinetweet, {body, :"$2"})
    IO.inspect offlineTweets
    if Kernel.length(offlineTweets) ==  0 do
        IO.inspect "No pending tweets"
    else
        :ets.delete(:offlinetweet, body)
        push socket, "new_msg", %{body: offlineTweets}
    end
    {:noreply, socket}
  end

   def handle_in("subscribesearch", payload, socket) do
    li = :ets.match(:subscribedtweet, {payload["body"], :"$2"})
    IO.inspect li
    push socket, "new_msg", %{body: li}
    {:noreply, socket}
  end

  def handle_in("usertagsearch", payload, socket) do
    li = :ets.match(:usertag, {payload["body"], :"$2"})
    IO.inspect li
    push socket, "new_msg", %{body: li}
    {:noreply, socket}
  end

  def handle_in("hashtagsearch", payload, socket) do
    li = :ets.match(:hashtag, {payload["body"], :"$2"})
    IO.inspect li
    push socket, "new_msg", %{body: li}
    {:noreply, socket}
  end

  def handle_in("new_msg", payload, socket) do
    IO.inspect socket.id
    extractInfoFromMessage(payload["body"])
    li = getFollowers(payload["source"], payload["body"]) ++ [socket.id]
    #li = Enum.join([li, socket.id], ",")
    IO.inspect li
    broadcast! socket, "new_msg", %{body: payload["body"], value: li}
    {:noreply, socket}
  end

  def extractInfoFromMessage(message) do
    IO.puts message
    isPresent = String.contains? message, "@"
    if isPresent == true do
        li = String.split(message, " ", parts: 2)
        username = Enum.at(li,0)
        username = String.slice(username, 1..String.length(username))
        li = :ets.match(:usertag, {username, :"$2"})
        if Kernel.length(li) == 0 do
            li = message
        else
            li = Enum.at(li, 0)
            li = Enum.join([li, message], ",")
        end
        :ets.insert(:usertag, {username, li})
        li = :ets.match(:usertag, {username, :"$2"})
        IO.inspect username
        IO.inspect li
    end
    isPresent = String.contains? message, "#"
    if isPresent == true do
        {index, length}= :binary.match message, "#"
        hashTag = String.slice(message, index+1..String.length(message))
        li1 = :ets.match(:hashtag, {hashTag, :"$2"})
        if Kernel.length(li1) == 0 do
            li1 = message
        else
            li1 = Enum.at(li1, 0)
            li1 = Enum.join([li1, message], ",")
        end
        :ets.insert(:hashtag, {hashTag, li1})
        li1 = :ets.match(:hashtag, {hashTag, :"$2"})
        IO.inspect hashTag
        IO.inspect li1
    end
  end

  def getFollowers(index, message) do
     IO.puts "~~~~~~~~~Entering the followers section"
     li = :ets.match(:subscribe, {index, :"$2"})
     IO.inspect li
     li = Enum.at(li, 0)
     li = Enum.at(li, 0)
     IO.inspect li
     Enum.each li, fn item -> 
        sub = :ets.match(:subscribedtweet, {item, :"$2"})
        if Kernel.length(sub) == 0 do
            sub = [] ++ [message]
        else
            sub = Enum.at(sub, 0)
            sub = Enum.join([sub, message], ",")
        end
        # add entry into subscribed tables
        :ets.insert(:subscribedtweet, {item, sub})
        sub = :ets.match(:subscribedtweet, {item, :"$2"})
        IO.inspect sub
     end
     # check for online offline here
     offlineUsers = getOfflineUsers(li, 0, [])
     IO.puts "!!!!!!Offline users!!!!!!!"
     IO.inspect offlineUsers
     if offlineUsers != nil do
        li = li -- offlineUsers

        # add entry in the future tweet storage table
        Enum.each offlineUsers, fn item -> 
            sub = :ets.match(:offlinetweet, {item, :"$2"})
            if Kernel.length(sub) == 0 do
                sub = [] ++ [message]
            else
                sub = Enum.at(sub, 0)
                sub = Enum.join([sub, message], ",")
            end
            # add entry into subscribed tables
            :ets.insert(:offlinetweet, {item, sub})
            sub = :ets.match(:offlinetweet, {item, :"$2"})
            IO.inspect sub
        end
     end
     IO.inspect "~~~~~~Socket info ~~~~~~"
     sockets = Enum.reduce(li, [], fn(x, acc) -> 
        if Enum.at(:ets.match(:userinfo, {x, :"$2"}), 0) != nil do
            acc ++ Enum.at(:ets.match(:userinfo, {x, :"$2"}), 0) 
        end 
        end)
     IO.inspect sockets
     sockets 
  end


  def getOfflineUsers(li, index, offline) do
    if index < Kernel.length(li) do
        x = Enum.at(li, index)
        if Enum.at(:ets.match(:userinfo, {x, :"$2"}), 0) == nil do
           offline = offline ++ [x]
        end
        getOfflineUsers(li, index+1, offline)
    else
        offline
    end
  end

  def handle_in("subscribe", payload, socket) do
    #IO.inspect payload["source"]
    #IO.inspect payload["body"]
    li = :ets.match(:subscribe, {payload["body"], :"$2"})
    if Kernel.length(li) == 0 do
        li = [] ++ [payload["source"]]
    else
        li = Enum.at(li, 0)
        li = Enum.at(li, 0)
        IO.inspect li
        li = li ++ [payload["source"]]
        IO.inspect li
    end
    :ets.insert(:subscribe, {payload["body"], li})
    li = :ets.match(:subscribe, {payload["body"], :"$2"})
    IO.inspect li
    {:noreply, socket}
  end

  intercept ["new_msg"]
  def handle_out("new_msg", msg, socket) do
    IO.puts "Intercepted"
    #IO.inspect msg
    sockets = msg[:"value"]
    if Enum.member?(sockets, socket.id) == true do
        push socket, "new_msg", msg
    end
    
    {:noreply, socket}
  end
end