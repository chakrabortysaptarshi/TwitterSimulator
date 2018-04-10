// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket
// and connect at the socket path in "lib/web/endpoint.ex":
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/2" function
// in "lib/web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, pass the token on connect as below. Or remove it
// from connect if you don't care about authentication.

socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("room:lobby", {})

  let usernameInput = document.querySelector("#username-input")
  let loginButton = document.querySelector("#login")
  let chatInput = document.querySelector("#chat-input")
  let subscribeInput = document.querySelector("#subscribe-input")
  let subscribers = document.querySelector("#subscribers")
  // let subscribedSearch = document.querySelector("#subscribed")
  // let usertagSearch = document.querySelector("#usertag")
  // let hashtagSearch = document.querySelector("#hashtag")
  let search = document.querySelector("#search");
  let hashTagInput = document.querySelector("#hashtag-input")
  let messagesContainer = document.querySelector("#messages")
  
  loginButton.addEventListener("click", event => {
    channel.push("login", {body: usernameInput.value})
    //usernameInput.value = ""
    usernameInput.disabled = true;
  })

  search.addEventListener("click", event => {
    if (document.getElementById('radio100').checked)
      channel.push("subscribesearch", {body: usernameInput.value});
    else if(document.getElementById('radio101').checked)
      channel.push("usertagsearch", {body: usernameInput.value});
    else {
      if (hashTagInput.value.indexOf("#") != -1) {
        alert("Hash not allowed");
        return;
      }
       channel.push("hashtagsearch", {body: hashTagInput.value})
    }
  })
  
  
  subscribeInput.addEventListener("keypress", event => {
    if(event.keyCode === 13){
      if (usernameInput.value == subscribeInput.value) {
        alert("Not allowed to subscribe himself");
        return;
      }
      channel.push("subscribe", {body: subscribeInput.value, source:usernameInput.value})
      let messageItem = document.createElement("li");
      messageItem.innerText = subscribeInput.value
      subscribers.appendChild(messageItem);
      subscribeInput.value = ""
    }
  })

  chatInput.addEventListener("keypress", event => {
    if(event.keyCode === 13){
      channel.push("new_msg", {body: chatInput.value, source:usernameInput.value})
      chatInput.value = ""
    }
  })
  
  function retweet() {
    //alert(this.id);
    var str = this.id.split(']');
    channel.push("new_msg", {body: str[1], source:usernameInput.value})
    //chatInput.value = ""
  }

  channel.on("new_msg", payload => {
    let messageItem = document.createElement("li");
    let btn = document.createElement("BUTTON");
    let t = document.createTextNode("Retweet");
    let id = Date() +"]"+ payload.body;
    //console.log(id);
    btn.setAttribute("id", id);
    btn.appendChild(t);
    btn.onclick = retweet;
     
    messageItem.innerText = `[${Date()}] ${payload.body} `
    messagesContainer.appendChild(messageItem);
    messagesContainer.appendChild(btn);
    document.getElementById(id).classList.add('btn'); 
    document.getElementById(id).classList.add('btn-primary'); 
  })
  
  channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket
