<form method="POST" action="/register">
    @csrf
    <input name="name" required>
    <input name="email" type="email" required>
    @error('email') <p class="erro">{{ $message }}</p> @enderror
    <input name="password" type="password" required>
    <input name="password_confirmation" type="password" required>
    <button>Criar conta</button>
</form>
