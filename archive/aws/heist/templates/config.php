<?php
$servername = "localhost";
$username = "root";
$password = "password";
$dbname = "vulnerable_app";

// Create connection
$conn = new mysqli($servername, $username, $password);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Create database
$sql = "CREATE DATABASE IF NOT EXISTS $dbname";
if ($conn->query($sql) === TRUE) {
    echo "Database created successfully";
} else {
    echo "Error creating database: " . $conn->error;
}

// Select database
$conn->select_db($dbname);

// Create users table
$sql = "CREATE TABLE IF NOT EXISTS users (
    id INT(6) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(30) NOT NULL,
    password VARCHAR(30) NOT NULL
)";

if ($conn->query($sql) === TRUE) {
    echo "Table users created successfully";
} else {
    echo "Error creating table: " . $conn->error;
}

// Create articles table
$sql = "CREATE TABLE IF NOT EXISTS articles (
    id INT(6) UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL
)";

if ($conn->query($sql) === TRUE) {
    echo "Table articles created successfully";
} else {
    echo "Error creating table: " . $conn->error;
}

// Insert dummy user
$sql = "INSERT INTO users (username, password) VALUES ('admin', 'admin')";
if ($conn->query($sql) === TRUE) {
    echo "User created successfully";
} else {
    echo "Error creating user: " . $conn->error;
}

$conn->close();
?>
