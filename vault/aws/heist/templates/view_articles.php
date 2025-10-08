<?php
include 'db.php';

$query = "SELECT * FROM articles";
$result = mysqli_query($conn, $query);
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechTalks - View Articles</title>
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
        <h1>Articles</h1>
        <?php while ($row = mysqli_fetch_assoc($result)) { ?>
            <div class="article">
                <h2><?php echo $row['title']; ?></h2>
                <p><?php echo $row['content']; ?></p>
            </div>
        <?php } ?>
    </div>
</body>
</html>
