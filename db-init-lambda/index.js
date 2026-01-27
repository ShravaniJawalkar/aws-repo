const mysql = require('mysql2/promise');

exports.handler = async (event) => {
    const dbConfig = {
        host: 'webproject-database.c14e66sq09ij.ap-south-1.rds.amazonaws.com',
        user: 'admin',
        password: 'PasswordwebProject2024',
        waitForConnections: true,
        connectionLimit: 1,
        queueLimit: 0
    };

    try {
        console.log('Connecting to RDS...');
        const connection = await mysql.createConnection(dbConfig);
        
        console.log('Creating database...');
        await connection.query('CREATE DATABASE IF NOT EXISTS webproject');
        console.log('✓ Database created');
        
        console.log('Creating table...');
        await connection.query(`CREATE TABLE IF NOT EXISTS webproject.image_uploads (
          id INT AUTO_INCREMENT PRIMARY KEY,
          fileName VARCHAR(255) NOT NULL UNIQUE,
          fileSize BIGINT,
          fileExtension VARCHAR(10),
          uploadedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          description TEXT,
          uploadedBy VARCHAR(100),
          INDEX idx_fileName (fileName)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`);
        console.log('✓ Table created');
        
        await connection.end();
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Database and table initialized successfully',
                database: 'webproject',
                table: 'image_uploads'
            })
        };
    } catch (error) {
        console.error('Error:', error.message);
        return {
            statusCode: 500,
            body: JSON.stringify({
                error: error.message
            })
        };
    }
};