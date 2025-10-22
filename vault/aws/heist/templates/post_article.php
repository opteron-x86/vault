<?php
include 'db.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $title = $_POST['title'];
    $content = $_POST['content'];

    $query = "INSERT INTO articles (title, content) VALUES ('$title', '$content')";
    if (mysqli_query($conn, $query)) {
        $message = "Article posted successfully";
    } else {
        $error = "Failed to post article";
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechTalks - Post Article</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="navbar">
        <a href="index.php">Home</a>
        <a href="about.php">About</a>
        <a href="contact.php">Contact</a>
        <a href="dashboard.php">Dashboard</a>
    </div>
    <div class="container">
        <h1>Post a New Article</h1>
        <form method="POST" action="">
            <label for="title">Title:</label>
            <input type="text" id="title" name="title" required>
            <label for="content">Content:</label>
            <textarea id="content" name="content" required></textarea>
            <button type="submit">Post</button>
        </form>
        <?php if (isset($message)) { echo "<p class='success'>$message</p>"; } ?>
        <?php if (isset($error)) { echo "<p class='error'>$error</p>"; } ?>
    </div>
</body>
</html>
