namespace Project.Application;

/// <summary>Application service — user operations</summary>
public class UserService
{
    private readonly IUserRepository _repo;
    private readonly IPasswordHasher _hasher;

    public UserService(IUserRepository repo, IPasswordHasher hasher)
    {
        _repo = repo;
        _hasher = hasher;
    }

    public async Task<User?> FindByEmailAsync(string email)
    {
        return await _repo.FindByEmailAsync(email);
    }

    public async Task<User> CreateAsync(CreateUserCommand cmd)
    {
        var hash = _hasher.Hash(cmd.Password);
        var user = User.Create(cmd.Email, hash);
        await _repo.SaveAsync(user);
        return user;
    }

    public async Task DisableAsync(Guid id)
    {
        var user = await _repo.FindByIdAsync(id)
            ?? throw new NotFoundException($"User {id} not found");
        user.Disable();
        await _repo.SaveAsync(user);
    }
}
