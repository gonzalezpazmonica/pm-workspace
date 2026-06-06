namespace Project.Domain;

/// <summary>User aggregate root</summary>
public class User
{
    public Guid Id { get; private set; }
    public string Email { get; private set; } = string.Empty;
    public string PasswordHash { get; private set; } = string.Empty;
    public bool Disabled { get; private set; }
    public DateTime? LastLoginAt { get; private set; }
    public DateTime CreatedAt { get; private set; }

    private User() { }

    public static User Create(string email, string passwordHash)
    {
        return new User
        {
            Id = Guid.NewGuid(),
            Email = email,
            PasswordHash = passwordHash,
            Disabled = false,
            CreatedAt = DateTime.UtcNow,
        };
    }

    public void Disable()
    {
        Disabled = true;
    }

    public void UpdateEmail(string newEmail)
    {
        Email = newEmail;
    }

    public void RecordLogin()
    {
        LastLoginAt = DateTime.UtcNow;
    }
}
