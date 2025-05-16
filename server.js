// server.js
const express = require("express");
const mongoose = require("mongoose");
const app = express();
app.use(express.json());

mongoose.connect("mongodb+srv://username:password@cluster.mongodb.net/myDatabase");

const userSchema = new mongoose.Schema({ name: String });
const User = mongoose.model("User", userSchema);

app.get("/users", async (req, res) => {
  const users = await User.find();
  res.json(users);
});

app.listen(3000, () => console.log("Server started"));
