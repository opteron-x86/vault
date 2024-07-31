<?php
if ($_SERVER['REQUEST_METHOD'] == 'POST' && isset($_FILES['file'])) {
    $target_dir = "uploads/";
    $target_file = $target_dir . basename($_FILES["file"]["name"]);
    move_uploaded_file($_FILES["file"]["tmp_name"], $target_file);
    $message = "File uploaded successfully";
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechTalks - File Upload</title>
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
        <h1>Upload a File</h1>
        <form method="POST" enctype="multipart/form-data">
            <label for="file">Select file to upload:</label>
            <input type="file" name="file" id="file" required>
            <button type="submit">Upload</button>
        </form>
        <?php if (isset($message)) { echo "<p class='success'>$message</p>"; } ?>
    </div>
</body>
</html>
