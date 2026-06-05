import { Component, OnInit, Input, Output, EventEmitter } from '@angular/core'

@Component({
  selector: 'app-user-list',
  templateUrl: './user-list.component.html',
  styleUrls: ['./user-list.component.scss'],
})
export class UserListComponent implements OnInit {
  @Input() projectId: string = ''
  @Output() userSelected = new EventEmitter<User>()

  users: User[] = []
  loading = false
  error: string | null = null

  ngOnInit(): void {
    this.loadUsers()
  }

  loadUsers(): void {
    this.loading = true
    // fetch users from service
  }

  selectUser(user: User): void {
    this.userSelected.emit(user)
  }

  trackByUserId(index: number, user: User): string {
    return user.id
  }
}
